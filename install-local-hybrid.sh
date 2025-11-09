#!/bin/bash

echo "🚀🚀🚀 Hybrid Infrastructure Setup 🚀🚀🚀"
echo "Infrastructure: Docker Compose"
echo "Applications: Kubernetes (Kind)"
echo ""


###
echo "=== Step 1: Start Docker Compose Infrastructure ==="
cd docker/local-hybrid
echo "Starting MySQL, MongoDB, Kafka, Redis via Docker Compose..."
docker-compose up -d
echo ""

echo "Waiting for infrastructure to be ready..."
sleep 15
echo ""

echo "=== Checking Docker Compose services ==="
docker-compose ps
echo ""

echo "=== Initializing MongoDB users ==="
./init-mongodb-users.sh
echo ""

cd ../..


###
echo "=== Step 2: Create Kind Cluster (Lightweight) ==="
cd kind
echo "[create] cluster creating with hybrid configuration..."
kind create cluster --name istio-cluster --config=cluster-local-hybrid.yml

echo ""
echo "=== ingress nginx 설치"
echo "[create] create ingress-nginx namespace and resources"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo ""
echo "=== [wait] wait ingress-nginx namespace to be created"
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/ingress-nginx --timeout=30s
echo ""

echo ""
echo "=== ⛴️ create namespace 'dailyfeed' & istio-injection=enabled"
kubectl create namespace dailyfeed --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace dailyfeed istio-injection=enabled --overwrite
echo ""

echo "=== 🔧 patch ingress-nginx controller with hostPort configuration"
echo "[patch] applying hostPort and resource configuration"
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --patch-file ingress-nginx-hostport-patch.yaml
echo ""

echo "=== [wait] wait for ingress-nginx to be ready with hostPort"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
echo ""
cd ..


echo ""
echo "🔧 Patching Control Plane resource limits"
cd k8s
source patch-control-plane-simple.sh
echo ""

echo "🔧 Patching CoreDNS resource limits"
source patch-coredns-resources.sh
cd ..
echo ""


###
echo "=== Step 3: Setup Kubernetes Resources (ConfigMaps, Secrets) ==="
echo ""

echo " 🔑🔑🔑 create configmaps, secrets (pointing to Docker Compose infrastructure)"
cd helm/manifests/local
kubectl apply -f .
cd ../../..
echo ""

echo "=== Step 3.5: Initialize JWT Primary Key ==="
echo ""
echo "🔑 Initializing JWT primary key in database..."
cd scripts
source init-jwt-key.sh local  # Use local environment configuration
if [ $? -eq 0 ]; then
    echo "✅ JWT key initialization completed successfully"
else
    echo "⚠️  JWT key initialization failed, but continuing..."
    echo "   The application will create a key on startup, but may have race conditions with multiple replicas"
fi
cd ..
echo ""


###
echo "=== Step 4 : 🛜 create Nodeport services for debugging"
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

echo "=== 🛜 create storageclass 'local-path'"
kubectl apply -f kind/sc/storageclass.yaml
echo ""

echo ""
echo "🔍 Verifying Kubernetes cluster is fully ready before Istio installation..."
RETRY_COUNT=0
MAX_RETRIES=30
until kubectl get nodes &>/dev/null && kubectl get --raw /healthz &>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "   Waiting for API server to be fully ready... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "⚠️  Cluster may not be fully ready, but continuing..."
else
  echo "✅ Cluster is ready for Istio installation"
fi
echo ""

echo ""
echo "⛴️ install istio === "
cd helm/istio
source istio-upgrade-install.sh
cd ../..
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

echo ""
echo "📊 install metrics-server for HPA === "
cd helm
source install-metrics-server.sh
cd ..
echo ""

echo ""
echo "✅✅✅ Hybrid Infrastructure Setup Complete ✅✅✅"
echo ""
echo "Infrastructure (Docker Compose):"
echo "  - MySQL:    localhost:23306"
echo "  - MongoDB:  localhost:27017"
echo "  - Redis:    localhost:26379"
echo "  - Kafka:    localhost:29092"
echo ""
echo ""
echo "Next steps:"
echo "  1. Deploy applications: cd ../dailyfeed-app-helm && source install-local.sh <version>"
echo "  2. Check infrastructure: docker-compose -f docker/local-hybrid/docker-compose.yaml ps"
echo "  3. Check Kubernetes: kubectl get all -n dailyfeed"
echo ""
