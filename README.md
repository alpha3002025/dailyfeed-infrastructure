# install
local
```bash
cd helm
source 1-install-essential-local.sh
```

dev
```bash
cd helm
source 1-install-essential-dev.sh
```
<br/>

# uninstall
local
```bash
cd helm
source 1-uninstall-essential-local.sh
```

dev
```bash
cd helm
source 1-uninstall-essential-dev.sh
```
<br/>


# mysql
- local: helm/docker-compose (가급적 helm 기반으로 해주시기 바랍니다.)
- dev: rds
  - `./manifests/dev` 내의 `mysql-config-dev` 내에 rds 엔드포인트를 입력해주시고 `mysql-secret-dev` 내에 user/password 를 각각 base64 encoding 해서 기입한 후 kubectl apply -f 해주시기 바랍니다. 

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
- local, dev 클러스터 각각에서 `dailyfeed-mysql` 을 기동시켜줘야합니다. 
- 각각의 APPLICATION 에서는 configmap, secret 으로 환경변수를 통해 MYSQL 주소를 가져올수는 있지만 ... 
- MYSQL 주소의 경우 가급적 이 `dailyfeed-mysql-service.yaml` 을 통해 생성한 `dailyfeed-mysql.infra.svc.cluster.local` 을 사용하는 것이 infrastructure 변경에 의존하지 않은 개발을 할수 있습니다.
- password, username 등은 Secret 을 통해, schema 는 Configmap 을 통해 가져오면 됩니다.

<br/>

# redis
- local: helm/docker-compose (가급적 helm 기반으로 해주시기 바랍니다.)
- dev: helm (redis-master.infra.svc.cluster.local)
- local: helm (redis-master.infra.svc.cluster.local)

helm 구동 스크립트
```sh
helm -n infra install redis oci://registry-1.docker.io/bitnamicharts/redis --set architecture=standalone --set auth.enabled=false --set master.persistence.enabled=false
```
- 각각의 클러스터 내에서 위의 명령을 통해 수동으로 설치하시면 됩니다. shell script 는 `./kafka_redis/setup.sh` 에 있습니다.
- Redis 의 경우 ElasticCache 를 사용할 경우 비용이 발생하는데, 개인 프로젝트에서 비용을 크게 발생시킬 필요가 없어보여서 ElasticCache 는 사용하지 않고 helm 을 통해 구성했습니다.

<br/>

# kafka
- local: helm/docker-compose (가급적 helm 기반으로 해주시기 바랍니다.)
- dev: helm (kafka.infra.svc.cluster.local)
- local: helm (kafka.infra.svc.cluster.local)

helm 구동 스크립트
```sh
helm -n infra install kafka oci://registry-1.docker.io/bitnamicharts/kafka --set controller.replicaCount=3  --set sasl.client.passwords=kafkakafka123! --set controller.persistence.enabled=false --set broker.persistence.enabled=false
```
- 각각의 클러스터 내에서 위의 명령을 통해 수동으로 설치하시면 됩니다. shell script 는 `./kafka_redis/setup.sh` 에 있습니다.
- Kafka 의 경우 클라우드 플랫폼 또는 AWS 인프라를 사용할 경우 비용이 발생하는데, 개인 프로젝트에서 비용을 크게 발생시킬 필요가 없어보여서 helm 을 통해 약식으로 구성했습니다.
<br/>

