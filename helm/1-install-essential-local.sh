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
#kubectl apply -f manifests/local/local-config-secret.yaml
cd manifests/local
kubectl apply -f .
cd ../..
echo ""


## install kafka, redis
echo " 📦📦📦 install kafka, redis, mysql, mongodb"
cd kafka_redis_mysql
source local-setup.sh
cd ..
echo ""

## networking
echo " 🛜🛜🛜 install services"
kubectl apply -n infra -f kafka_redis_mysql/local-mysql-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/local-mongodb-service.yaml

#echo "wait 60s (mysql pending) "
#sleep 60
#
### fort-forwarding
#echo "port-forward -n infra svc/mysql 3306:3306 &"
#kubectl port-forward -n infra svc/mysql 3306:3306 &
