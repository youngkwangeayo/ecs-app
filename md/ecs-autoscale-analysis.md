# ECS Auto Scaling 분석 보고서

## 문제 상황
- `yes > /dev/null`로 CPU 부하 생성하여 스케일아웃 발생
- yes 프로세스 종료 후 CPU 사용률 하락
- 스케일인이 예상보다 늦게 발생 (약 18분 소요)

## 서비스 정보
- **클러스터**: `ecs-dev-mysolution`
- **서비스**: `service-dev-myapp`
- **리전**: `ap-northeast-2`

## Auto Scaling 설정

### Scalable Target
```json
{
  "MinCapacity": 1,
  "MaxCapacity": 3,
  "ScalableDimension": "ecs:service:DesiredCount"
}
```

### Scaling Policy
```yaml
PolicyName: autoScale-dev-coffeezip
PolicyType: TargetTrackingScaling
TargetTrackingScalingPolicyConfiguration:
  TargetValue: 70.0
  PredefinedMetricType: ECSServiceAverageCPUUtilization
  ScaleInCooldown: 120    # 2분
  ScaleOutCooldown: 60    # 1분
  DisableScaleIn: false
```

## 스케일링 타임라인

| 시간 | 이벤트 | Task 수 | 원인 |
|------|--------|---------|------|
| 09:51 | Scale Out | 1 → 2 | CPU > 70% (AlarmHigh) |
| 09:54 | Scale Out | 2 → 3 | CPU > 70% (AlarmHigh) |
| 10:12 | Scale In | 3 → 2 | CPU < 63% (AlarmLow) |

**스케일인 소요 시간**: 09:54 → 10:12 = **18분**

## 스케일인이 늦어진 이유

### 1. Cooldown Period (최소 대기시간)
- `ScaleInCooldown: 120초` (2분)
- 마지막 스케일링 이후 최소 2분은 대기해야 함
- 단, 이것은 최소 조건일 뿐

### 2. CloudWatch 알람 평가 메커니즘
```json
{
  "AlarmName": "AlarmLow",
  "StateValue": "ALARM",
  "StateReason": "Threshold Crossed: 15 datapoints were less than the threshold (63.0)",
  "Threshold": 63.0,
  "RecentDatapoints": [
    "1.14% (01:07:00)",
    "1.16% (01:06:00)",
    "1.17% (01:05:00)",
    "1.18% (01:04:00)",
    "1.16% (01:03:00)"
  ]
}
```

**핵심**: 알람이 ALARM 상태로 전환되려면 **15개의 연속된 낮은 CPU 데이터포인트**가 필요

### 3. 데이터 수집 주기
- CloudWatch 메트릭 수집 주기: **1분**
- 15개 데이터포인트 필요 = **최소 15분**
- 모든 데이터포인트가 임계값 이하여야 함

### 4. Target Tracking 계산 방식
Target Tracking Scaling은 내부적으로 2개의 CloudWatch 알람을 생성:
- **AlarmHigh**: ScaleOut 트리거 (TargetValue보다 높을 때)
- **AlarmLow**: ScaleIn 트리거 (TargetValue * 0.9보다 낮을 때)

ScaleIn 임계값 = 70% × 0.9 = **63%**

### 5. 안전성 우선 설계
AWS Auto Scaling은 다음을 방지하기 위해 보수적으로 동작:
- 일시적인 CPU 하락으로 인한 불필요한 스케일인
- 짧은 시간 내 반복적인 스케일 인/아웃 (flapping)
- 서비스 안정성 저하

## 스케일인 지연 계산

```
총 소요 시간 = Cooldown + 데이터 수집 + 알람 평가
             = 2분 + 15분 + α
             ≈ 18분
```

## 진단 스크립트

### 1. Auto Scaling 설정 확인
```bash
# Scalable Target 확인
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/ecs-dev-mysolution/service-dev-myapp \
  --region ap-northeast-2

# Scaling Policy 확인
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/ecs-dev-mysolution/service-dev-myapp \
  --region ap-northeast-2 \
  --output yaml
```

### 2. 스케일링 활동 이력 확인
```bash
# 최근 20개 스케일링 활동
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/ecs-dev-mysolution/service-dev-myapp \
  --region ap-northeast-2 \
  --max-results 20 \
  | jq '.ScalingActivities[] | {
      StartTime,
      Description,
      Cause,
      StatusCode,
      StatusMessage
    }'
```

### 3. 현재 서비스 상태 확인
```bash
# Task 수 확인
aws ecs describe-services \
  --cluster ecs-dev-mysolution \
  --services service-dev-myapp \
  --region ap-northeast-2 \
  | jq '.services[0] | {
      desiredCount,
      runningCount,
      pendingCount
    }'
```

### 4. CloudWatch 알람 상태 확인
```bash
# ScaleIn 알람 확인
aws cloudwatch describe-alarms \
  --alarm-names "TargetTracking-service/ecs-dev-mysolution/service-dev-myapp-AlarmLow-94f162d9-9fb1-45db-8092-41cf5dd4f49a" \
  --region ap-northeast-2 \
  | jq '.MetricAlarms[0] | {
      AlarmName,
      StateValue,
      StateReason,
      Threshold,
      MetricName
    }'
```

### 5. CPU 메트릭 확인 (macOS)
```bash
# 최근 30분 CPU 사용률
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=service-dev-myapp Name=ClusterName,Value=ecs-dev-mysolution \
  --start-time $(date -u -v-30M '+%Y-%m-%dT%H:%M:%S') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \
  --period 60 \
  --statistics Average \
  --region ap-northeast-2 \
  | jq -r '.Datapoints | sort_by(.Timestamp) | .[-15:] | .[] | "\(.Timestamp) - CPU: \(.Average)%"'
```

### 6. 실시간 모니터링
```bash
# 5초마다 Task 수 확인
watch -n 5 'aws ecs describe-services \
  --cluster ecs-dev-mysolution \
  --services service-dev-myapp \
  --region ap-northeast-2 \
  | jq ".services[0] | {desiredCount, runningCount, pendingCount}"'
```

### 7. Scaling 일시 중단 여부 확인
```bash
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/ecs-dev-mysolution/service-dev-myapp \
  --region ap-northeast-2 \
  | jq '.ScalableTargets[0].SuspendedState'
```

## 결론

### 원인
스케일인 지연은 **버그가 아닌 정상 동작**입니다.

1. ✅ Auto Scaling 설정 정상
2. ✅ CloudWatch 알람 정상 작동
3. ✅ 15개 데이터포인트 수집 후 스케일인 실행
4. ✅ Cooldown 시간 준수

### 개선 방안 (필요시)

#### 1. ScaleIn을 더 빠르게 하려면
```bash
# ScaleInCooldown 줄이기 (120초 → 60초)
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/ecs-dev-mysolution/service-dev-myapp \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name autoScale-dev-coffeezip \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleInCooldown": 60,
    "ScaleOutCooldown": 60
  }' \
  --region ap-northeast-2
```

**주의**: Cooldown을 너무 짧게 하면:
- ⚠️ 빈번한 스케일 인/아웃 발생 (flapping)
- ⚠️ 서비스 불안정
- ⚠️ 비용 증가 (task 시작/종료 반복)

#### 2. Step Scaling으로 변경 (더 세밀한 제어)
Target Tracking 대신 Step Scaling을 사용하면 알람 평가 기준을 직접 설정 가능

하지만 **대부분의 경우 Target Tracking이 권장됨**

### 권장사항
- ✅ 현재 설정 유지 (정상 작동 중)
- ✅ ScaleInCooldown: 120초 (2분) - 적절함
- ✅ TargetValue: 70% - 적절함
- ⚠️ 급격한 트래픽 변화가 있다면 ScaleOutCooldown을 30초로 단축 고려

## 참고 자료
- [AWS Auto Scaling - Target Tracking](https://docs.aws.amazon.com/autoscaling/application/userguide/application-auto-scaling-target-tracking.html)
- [ECS Service Auto Scaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
