
```bash
aws ecs describe-services --cluster ecs-dev-myapp --services service-dev-myapp >> aws/service.json

aws ecs describe-task-definition --task-definition task-dev-myapp >> aws/taskdef.json
```
