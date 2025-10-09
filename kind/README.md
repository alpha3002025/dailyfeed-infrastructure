install
```bash
source create-cluster.sh
```

uninstall
- Orbstack 또는 Docker Desktop 에서 삭제


test
```bash
## Check
kubectl get po
No resources found in default namespace.

## testnginx pod 기동
kubectl run testnginx --image=nginx:latest
pod/testnginx created

## 상태 확인
kubectl get po
NAME        READY   STATUS              RESTARTS   AGE
testnginx   0/1     ContainerCreating   0          5s

## testnginx pod 삭제
kubectl delete po testnginx
pod "testnginx" deleted
```

# 디버깅 포트
- 개발 PC Port : 8888 (kind 에 8888(호스트PC) -> 30888(kind) 로 매핑)
- NodePort Port : 30888 (Node 의 port(kind 의 port))
- Service Port : 8080 (Service port)
- Container Port : 8080 (Container Port (앱))
