echo ""
echo "=== create Cluster & Ingress-Nginx (Ingress Controller) ==="
echo "[create] cluster creating..."
kind create cluster --name istio-cluster --config=cluster.yml

echo ""
echo "=== ingress nginx 설치"
echo "[create] create ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo ""
echo "=== [wait] wait ingress-nginx standby"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
