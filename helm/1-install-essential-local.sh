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


## install kafka, redis, mongodb
echo " 📦📦📦 install kafka, redis, mysql, mongodb"
cd kafka_redis_mysql
source local-setup.sh
cd ..
echo ""

## networking
echo " 🛜🛜🛜 install services"
kubectl apply -n infra -f kafka_redis_mysql/local-mysql-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/local-redis-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/local-mongodb-service.yaml
echo ""

#echo "wait 60s (mysql pending) "
#sleep 60
#
### fort-forwarding
#echo "port-forward -n infra svc/mysql 3306:3306 &"
#kubectl port-forward -n infra svc/mysql 3306:3306 &

echo ""
echo "⛴️ create namespace 'dailyfeed' & istio-injection=enabled"
kubectl create namespace dailyfeed
kubectl label namespace dailyfeed istio-injection=enabled
echo ""

echo ""
echo "✏️ check -n dailyfeed === "
kubectl get all -n dailyfeed
echo ""


echo ""
echo "⛴️ install istio === "
cd istio
source istio-upgrade-install.sh
cd ..
echo ""


echo ""
echo "✏️ check -n infra === "
kubectl get all -n infra
echo ""

echo ""
echo "✏️ check -n dailyfeed === "
kubectl get all -n dailyfeed
echo ""


echo ""
echo "✏️ check -n istio-system === "
kubectl get all -n istio-system
echo ""

echo ""
echo "✏️ check -n istio-ingress === "
kubectl get pods -n istio-ingress
echo ""

