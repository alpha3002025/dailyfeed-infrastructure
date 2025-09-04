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
```
