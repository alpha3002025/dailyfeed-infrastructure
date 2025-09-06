## configmap, secret
kubectl create ns dailyfeed
## infra
kubectl create ns infra
## install configmap, secret
#kubectl apply -f manifests/local/local-config-secret.yaml
cd manifests/local
kubectl apply -f .
cd ../..
## install kafka, redis
cd kafka_redis_mysql
source local-setup.sh
cd ..
## install mysql
kubectl apply -n infra -f kafka_redis_mysql/local-mysql-service.yaml

echo "wait 60s (mysql pending) "
sleep 60

## fort-forwarding
echo "port-forward -n infra svc/mysql 3306:3306 &"
kubectl port-forward -n infra svc/mysql 3306:3306 &
