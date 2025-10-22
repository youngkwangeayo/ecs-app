# ecs-app
aws-ecs-app-provisioning




## 네트워크
> VPC : prod-vpc
> subnet : private a~b AZ
> 도메인
> myapp.domain.co.kr

## Cluster
> - clustername : ecs-dev-mysolution
> - 컴퓨팅 : FarGate

> > # service : service-dev-myapp
> > > - 로드밸런서 : cms-elb 
> > > - target group : group-dev-myapp ( ip 타입)
> > >   헬스체크 유예 90초
> > > - Auto Scaling enable, 조정정책 AverrageCPU 임계치 70
> > >   임계치 넘어가고 휴지시간동안은 유지, 클라우드워치메트릭으로 약 15번 (1분에1번) 통과로 스케일인, 약5번(5분)으로 스케일아웃

> > # task : task-dev-myapp
> > > container :  myapp
> > > ECR : my-ecr/myapp
> > > 제한시간 시작: 90 , 중지 : 120
> > > 컨테이너상태  CMD-SHELL,curl -f http://localhost:8080/health || exit 1
 

## bitbucket
> > ci/cd
> > pipeline + sh 
> > repo : myapp

 
## OCI  이미지 : Docker 