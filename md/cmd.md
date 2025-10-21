
```bash

aws ecs describe-clusters --clusters ecs-dev-myapp >> aws/cluster.json

aws ecs describe-services --cluster ecs-dev-myapp --services service-dev-myapp >> aws/service.json

aws ecs describe-task-definition --task-definition task-dev-myapp >> aws/taskdef.json

aws application-autoscaling describe-scalable-targets --service-namespace ecs --resource-ids service/ecs-dev-myapp/service-dev-myapp >> aws/autoscal.json


```
