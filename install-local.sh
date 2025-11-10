echo "🛺🛺 install kind 😆😆 "
cd kind
source create-cluster.sh
cd ..
echo ""

echo ""
echo "🔧 Patching Control Plane resource limits"
cd k8s
source patch-control-plane-resources.sh
echo ""

echo "🔧 Patching CoreDNS resource limits"
source patch-coredns-resources.sh
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

echo "=== 🛜 create Nodeport 'dailyfeed-content-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-content-debug-svc.yaml
echo ""

echo "=== 🛜 create Nodeport 'dailyfeed-timeline-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-timeline-debug-svc.yaml
echo ""

echo "=== 🛜 create Nodeport 'dailyfeed-activity-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-activity-debug-svc.yaml
echo ""

echo "=== 🛜 create Nodeport 'dailyfeed-image-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-image-debug-svc.yaml
echo ""

echo "=== 🛜 create Nodeport 'dailyfeed-search-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-search-debug-svc.yaml
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


echo "=== 🛜 create storageclass 'local-path'"
kubectl apply -f kind/sc/storageclass.yaml
echo ""


echo "🛺🛺 install istio ingress gateway, virtualservice 😆😆 "
kubectl apply -f istio/ingress/gateway.yaml
kubectl apply -f istio/ingress/virtualservice.yaml
echo ""


echo "🛺🛺 install istio addons 😆😆 "
cd istio-addon
echo "🛜🛜🛜 install kiali"
kubectl apply -f kiali.yaml
echo ""

echo "🛜🛜🛜 install jaeger"
kubectl apply -f jaeger.yaml
echo ""

echo "🛜🛜🛜 install prometheus"
kubectl apply -f prometheus.yaml
echo ""

echo "🛜🛜🛜 install grafana"
kubectl apply -f grafana.yaml
cd ..
echo ""

echo "🔌 install Kiali, Jaeger, Prometheus, Grafana Nodeport"
cd istio-addon/nodeport
kubectl apply -f .
echo ""
cd ../..

echo ""