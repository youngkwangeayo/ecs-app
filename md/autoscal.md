# ECS AutoScale


## ECS - SERVICE -> 서비스 
> ### 1 서비스 자동 크기 조정 활성
>>  최소 사이즈, 최대 사이즈 설정
> ### !주의!
>> 조정정책을 추가안하면 오토스케일안됨.  1번은 정의만 하는거임
> ### 2 조정정책 구성
>> 서비스지표에서 CPU 선택 ( ECSServiceAverageCPUUtilzation ) 

## 확인 커맨드 
>   aws application-autoscaling describe-scalable-targets --service-namespace ecs --resource-ids service/ecs-dev-myapp/service-dev-myapp >> aws/autoscal.json



ECSServiceAverageCPUUtilization



```bash
# 오토스케일 확인

aws ecs describe-services \
  --cluster ecs-dev-coffeezip \
  --services service-dev-coffeezip-cms \
  --query 'services[0].{desiredCount:desiredCount, runningCount:runningCount}' \
  --output table

```


```bash
# 직접 부하 테스트

# ECS Task 내에서 직접 부하 생성
yes > /dev/null &

# 또는
node -e "while(true){}"

```


```bash
# 간접 부하 테스트 부하 도구(ab or hey or wrk)

# -n 총요청수, -c 동시요청수
ab -n 100000 -c 50 https://your-alb-endpoint/

# 예: 2분 동안 동시 100 연결로 요청
hey -z 2m -c 100 https://your-alb-endpoint/path

# 특정 헤더, POST 등
hey -z 2m -c 100 -H "Authorization: Bearer TOKEN" -m POST -d '{"x":"y"}' https://...

# -t threads, -c connections, -d duration
wrk -t12 -c400 -d120s https://your-alb-endpoint/path


cat <<'EOF' > headers.lua
wrk.method = "GET"
wrk.headers["Authorization"] = "Bearer eyJhbGciOiJIUz.."
wrk.headers["Content-Type"] = "application/json"
wrk.headers["Accept"] = "application/json"
EOF

wrk -t4 -c200 -d2m -s headers.lua https://your-alb-endpoint/api/health
```

```bash
# 접속

aws ecs execute-command \
  --cluster ecs-dev-coffeezip \
  --task <TASK_ID> \
  --container <CONTAINER_NAME> \
  --command "/bin/sh" \
  --interactive

```
