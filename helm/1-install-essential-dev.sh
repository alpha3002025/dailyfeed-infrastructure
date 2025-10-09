echo "🖨️🖨️🖨️  create namespace 'dailyfeed'"
## configmap, secret
kubectl create ns dailyfeed
echo ""


## infra
echo " 🖨️🖨️🖨️  create namespace 'infra'"
kubectl create ns infra
echo ""


## install configmap, secret
echo " 🔑🔑🔑 create configmaps, secrets"
cd manifests/dev
kubectl apply -f .
cd ../..
echo ""


## install kafka, redis, mongodb
echo " 📦📦📦 install kafka, redis, mysql"
cd kafka_redis_mysql
source dev-setup.sh
cd ..
echo ""

## networking
echo " 🛜🛜🛜 install services"
kubectl apply -n infra -f kafka_redis_mysql/dev-mysql-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/dev-redis-service.yaml
## ExternerService 로 대체 예정
# kubectl apply -n infra -f kafka_redis_mysql/dev-mongodb-service.yaml

#echo "wait 60s (mysql pending) "
#sleep 60
#
### fort-forwarding
#echo "port-forward -n infra svc/mysql 3306:3306 &"
#kubectl port-forward -n infra svc/mysql 3306:3306 &

echo "⛴️ create namespace 'dailyfeed' & istio-injection=enabled"
kubectl create namespace dailyfeed
kubectl label namespace istio-injection=enabled
