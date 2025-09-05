## configmap, secret
kubectl create ns dailyfeed
## infra
kubectl create ns infra
## install configmap, secret
kubectl apply -f manifests/dev/dev-config-secret.yaml
## install kafka, redis
cd kafka_redis
source setup.sh
cd ..
## install mysql
kubectl apply -n infra -f kafka_redis_mysql/dev-mysql-service.yaml