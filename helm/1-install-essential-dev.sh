echo "🖨️🖨️🖨️  create namespace 'dailyfeed'"
kubectl create ns dailyfeed
echo ""


echo "🖨️🖨️🖨️  create namespace 'infra'"
kubectl create ns infra
echo ""


## install configmap, secret
echo "🔑🔑🔑 create configmaps, secrets"
cd manifests/dev
kubectl apply -f .
cd ../..
echo ""


## install kafka, redis (dev 환경에서는 MySQL, MongoDB는 외부 서비스 사용)
echo "📦📦📦 install kafka, redis"
cd kafka_redis_mysql
source dev-setup.sh
cd ..
echo ""


## networking - ExternalName Services for MySQL RDS and MongoDB Atlas
echo "🛜🛜🛜 install external services (MySQL RDS, MongoDB Atlas)"
kubectl apply -n infra -f kafka_redis_mysql/dev-mysql-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/dev-mongodb-service.yaml
kubectl apply -n infra -f kafka_redis_mysql/dev-redis-service.yaml
echo ""


echo ""
echo "⛴️ label namespace 'dailyfeed' with istio-injection=enabled"
kubectl label namespace dailyfeed istio-injection=enabled --overwrite
echo ""


echo ""
echo "✏️ check -n dailyfeed"
kubectl get all -n dailyfeed
echo ""


echo ""
echo "⛴️ install istio"
cd istio
source istio-upgrade-install.sh
cd ..
echo ""


echo ""
echo "📊 install metrics-server for HPA"
source install-metrics-server.sh
echo ""


echo ""
echo "✏️ check -n infra"
kubectl get all -n infra
echo ""


echo ""
echo "✏️ check -n dailyfeed"
kubectl get all -n dailyfeed
echo ""


echo ""
echo "✏️ check -n istio-system"
kubectl get all -n istio-system
echo ""


echo ""
echo "✏️ check -n istio-ingress"
kubectl get pods -n istio-ingress
echo ""
