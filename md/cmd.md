
```bash
# 서비스 구성 

aws ecs describe-clusters --clusters ecs-dev-myapp >> aws/cluster.json

aws ecs describe-services --cluster ecs-dev-myapp --services service-dev-myapp >> aws/service.json

aws ecs describe-task-definition --task-definition task-dev-myapp >> aws/taskdef.json

```


```bash
# 오토 스케일

# 오토스케일 정의
aws application-autoscaling describe-scalable-targets --service-namespace ecs --resource-ids service/ecs-dev-myapp/service-dev-myapp >> aws/autoscal.json
# 오토스케일 정책 트리거
aws application-autoscaling describe-scaling-policies \                                                                                                              
  --service-namespace ecs \
  --resource-id service/ecs-dev-myapp/service-dev-myapp \
  --output yaml \
  >> aws/scaling-policies.yaml


# 상태확인
aws ecs describe-services \
  --cluster ecs-dev-coffeezip \
  --services service-dev-coffeezip-cms \
  --query 'services[0].{desiredCount:desiredCount, runningCount:runningCount}' \
  --output table

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
