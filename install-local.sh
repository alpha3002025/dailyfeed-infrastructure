echo "🛺🛺 install kind 😆😆 "
cd kind
source create-cluster.sh
cd ..
echo ""

echo "🛺🛺 install tasks in ./helm/** 😆😆 "
cd helm
source 1-install-essential-local.sh
cd ..
echo ""


echo "=== 🛜 create Nodeport 'dailyfeed-member-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-member-debug-svc.yaml
echo ""


echo "=== 🛜 create Nodeport 'mysql-nodeport'"
kubectl apply -f kind/nodeport/mysql-nodeport.yaml
echo ""


echo "=== 🛜 create Nodeport 'redis-nodeport'"
kubectl apply -f kind/nodeport/redis-nodeport.yaml
echo ""


echo "=== 🛜 create Nodeport 'mongodb-nodeport'"
kubectl apply -f kind/nodeport/mongodb-nodeport.yaml
echo ""


echo "🛺🛺 install istio ingress gateway, virtualservice 😆😆 "
kubectl apply -f istio/ingress/gateway.yaml
kubectl apply -f istio/ingress/virtualservice.yaml
echo ""


echo "🛺🛺 install istio addons 😆😆 "
cd istio-addon
echo "🛜🛜🛜 isntall kiali"
kubectl apply -f kiali.yaml
echo ""

echo "🛜🛜🛜 isntall jaeger"
kubectl apply -f jaeger.yaml
echo ""

echo "🛜🛜🛜 isntall prometheus"
kubectl apply -f prometheus.yaml
cd ..
echo ""

echo "🔌 install Kiali, Jaeger, Prometheus Nodeport"
cd istio-addon/nodeport
kubectl apply -f .
echo ""
cd ../..

echo ""