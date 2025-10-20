#!/bin/bash


set -e

AWS_ECS_CLUSTER=ecs-coffee-cms-copy
AWS_ECS_SERVICE=task-coffee-cms-copy-service-mpp7whl3
AWS_TASK_DEFINITION="task-coffee-cms-copy-new"

TAG=''

# 버전 read input
while true; do
        echo 'Enter the version to deploy'
        echo 'Example : 0.0.1'

        read TAG

        if [[ $TAG =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "ENV Prod Deployment : $TAG"
                break
        else
                echo "Invalid version format. Please use format: number.number.number (e.g., 1.2.3)"
        fi
done



# Get all revisions and find the one with matching tag
REVISIONS=$(aws ecs list-task-definitions --family-prefix $AWS_TASK_DEFINITION --sort DESC --query 'taskDefinitionArns[]' --output text)

TARGET_REVISION=""
for revision_arn in $REVISIONS; do
    revision_num=$(echo $revision_arn | rev | cut -d: -f1 | rev)
    image=$(aws ecs describe-task-definition --task-definition $AWS_TASK_DEFINITION:$revision_num --query 'taskDefinition.containerDefinitions[0].image' --output text)

    if [[ "$image" == *":$TAG" ]]; then
        TARGET_REVISION=$revision_num
        echo "Found matching revision: $TARGET_REVISION with image: $image"
        break
    fi
done

if [[ -z "$TARGET_REVISION" ]]; then
    echo "Error: No task definition found with tag: $TAG"
    exit 1
fi

# 2. Update service with found revision
echo "Updating ECS service with revision: $TARGET_REVISION"
aws ecs update-service \
  --cluster $AWS_ECS_CLUSTER \
  --service $AWS_ECS_SERVICE \
  --task-definition $AWS_TASK_DEFINITION:$TARGET_REVISION \
  --force-new-deployment \
  --no-cli-pager

echo "Service update initiated. Using revision: $TARGET_REVISION"

# 3. Wait for deployment to complete (optional)
echo "원바이원으로 실행됩니다. 오래걸리니 AWS콘솔창을 확인해주세요..."
echo "Waiting for deployment to complete..."
aws ecs wait services-stable --cluster $AWS_ECS_CLUSTER --services $AWS_ECS_SERVICE

echo "Deployment completed successfully!"