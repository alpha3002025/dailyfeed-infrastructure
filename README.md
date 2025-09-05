# mysql
- local: helm/docker-compose
- dev: rds
- prod: rds

infra 네임스페이스에 `dailyfeed-mysql` 에 url 연결
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dailyfeed-mysql
  namespace: infra
spec:
  type: ExternalName
  externalName: [rds 주소 or localhost]
```
<br/>

# redis
- local: helm/docker-compose
- dev: helm (redis.infra.svc.cluster.local)
- local: helm (redis.infra.svc.cluster.local)
```sh
helm -n infra install redis oci://registry-1.docker.io/bitnamicharts/redis --set architecture=standalone --set auth.enabled=false --set master.persistence.enabled=false
```
<br/>

# kafka
- local: helm/docker-compose
- dev: helm (kafka.infra.svc.cluster.local)
- local: helm (kafka.infra.svc.cluster.local)
```sh
helm -n infra install kafka oci://registry-1.docker.io/bitnamicharts/kafka --set controller.replicaCount=3  --set sasl.client.passwords=kafkakafka123! --set controller.persistence.enabled=false --set broker.persistence.enabled=false
```
<br/>
