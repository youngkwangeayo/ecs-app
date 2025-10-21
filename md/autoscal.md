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