echo ""
echo "=== create Cluster & Ingress-Nginx (Ingress Controller) ==="
echo "[create] cluster creating..."
kind create cluster --name istio-cluster --config=cluster.yml

echo ""
echo "=== ingress nginx 설치"
echo "[create] create ingress-nginx namespace and resources"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo ""
echo "=== [wait] wait ingress-nginx namespace to be created"
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/ingress-nginx --timeout=30s
echo ""

echo "=== 🔧 replace ingress-nginx controller with hostPort configuration"
echo "[delete] removing default ingress-nginx-controller deployment"
kubectl delete deployment ingress-nginx-controller -n ingress-nginx --ignore-not-found=true
echo ""

echo "[create] applying hostPort-enabled ingress-nginx-controller"
kubectl apply -f ingress-nginx-hostport.yaml
echo ""

echo "=== [wait] wait for ingress-nginx to be ready with hostPort"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
echo ""


echo ""
echo "=== 📇 create namespace 'dailyfeed'"
kubectl create namespace dailyfeed
echo ""


# echo ""
# echo "=== 🌄 image pull 'infra images'"
# source load-images-to-kind.sh
# echo ""