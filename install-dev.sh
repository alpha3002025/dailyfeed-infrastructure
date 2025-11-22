echo "🚀🚀🚀 Dev Environment Setup (Hybrid Mode) 🚀🚀🚀"
echo "Infrastructure: Docker Compose (Redis, Kafka) + External (MySQL, MongoDB)"
echo "Applications: Kubernetes (Kind)"
echo ""


###
echo "=== Step 1: Start Docker Compose Infrastructure (Redis, Kafka) ==="
cd docker/dev
echo "Starting Redis and Kafka via Docker Compose..."
docker-compose up -d
echo ""

echo "Waiting for infrastructure to be ready..."
sleep 15
echo ""

echo "=== Checking Docker Compose services ==="
docker-compose ps
echo ""

cd ../..


###
echo "=== Step 2: Create Kind Cluster ==="
echo "🛺🛺 install kind cluster 😆😆"
cd kind
source create-cluster.sh
cd ..
echo ""

echo ""
echo "=== 🔗 Connecting Kind cluster to Docker Compose network ==="
echo "This allows Kubernetes pods to directly access Docker Compose services"

# Kind 클러스터의 컨테이너를 dailyfeed-network에 연결
NETWORK_NAME="dev_dailyfeed-network"

# Kind 컨트롤 플레인 노드 연결
KIND_CONTROL_PLANE="istio-cluster-control-plane"
if docker ps --format '{{.Names}}' | grep -q "^${KIND_CONTROL_PLANE}$"; then
    echo "  → Connecting ${KIND_CONTROL_PLANE} to ${NETWORK_NAME}..."
    docker network connect ${NETWORK_NAME} ${KIND_CONTROL_PLANE} 2>/dev/null || echo "  ✓ Already connected"
else
    echo "  ⚠️  ${KIND_CONTROL_PLANE} not found"
fi

# Kind 워커 노드들 연결 (있는 경우)
for worker in $(docker ps --format '{{.Names}}' | grep "^istio-cluster-worker"); do
    echo "  → Connecting ${worker} to ${NETWORK_NAME}..."
    docker network connect ${NETWORK_NAME} ${worker} 2>/dev/null || echo "  ✓ Already connected"
done

echo "  ✅ Kind nodes connected to Docker Compose network"
echo ""

echo ""
echo "=== 🔗 Connecting Docker Compose infrastructure to Kind network ==="
echo "This allows CoreDNS to resolve infrastructure service hostnames"
echo ""

KIND_NETWORK="kind"

# Kafka 컨테이너들 연결
for kafka in kafka-1 kafka-2 kafka-3; do
    if docker ps --format '{{.Names}}' | grep -q "^${kafka}$"; then
        echo "  → Connecting ${kafka} to ${KIND_NETWORK}..."
        docker network connect ${KIND_NETWORK} ${kafka} 2>/dev/null || echo "  ✓ Already connected"
    else
        echo "  ⚠️  ${kafka} not found"
    fi
done

# Redis 컨테이너 연결
if docker ps --format '{{.Names}}' | grep -q "^redis-dailyfeed$"; then
    echo "  → Connecting redis-dailyfeed to ${KIND_NETWORK}..."
    docker network connect ${KIND_NETWORK} redis-dailyfeed 2>/dev/null || echo "  ✓ Already connected"
else
    echo "  ⚠️  redis-dailyfeed not found"
fi

echo "  ✅ Docker Compose containers connected to Kind network"
echo ""

echo ""
echo "🔧 Patching Control Plane resource limits"
cd k8s
source patch-control-plane-simple.sh
echo ""

echo "🔧 Patching CoreDNS resource limits"
source patch-coredns-resources.sh
echo ""

echo "🔧 Adding custom DNS entries for infrastructure services (Dev environment)"
source patch-coredns-custom-dns-dev.sh
cd ..
echo ""


echo "🛺🛺 install tasks in ./helm/** (dev profile) 😆😆"
cd helm
source 1-install-essential-dev.sh
cd ..
echo ""


echo "=== 🛜 create NodePort 'dailyfeed-member-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-member-debug-svc.yaml
echo ""

echo "=== 🛜 create NodePort 'dailyfeed-content-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-content-debug-svc.yaml
echo ""

echo "=== 🛜 create NodePort 'dailyfeed-timeline-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-timeline-debug-svc.yaml
echo ""

echo "=== 🛜 create NodePort 'dailyfeed-activity-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-activity-debug-svc.yaml
echo ""

echo "=== 🛜 create NodePort 'dailyfeed-image-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-image-debug-svc.yaml
echo ""

echo "=== 🛜 create NodePort 'dailyfeed-search-debug-svc'"
kubectl apply -f kind/nodeport/dailyfeed-search-debug-svc.yaml
echo ""


echo "=== 🛜 create storageclass 'local-path'"
kubectl apply -f kind/sc/storageclass.yaml
echo ""


echo "🛺🛺 install istio ingress gateway, virtualservice 😆😆"
kubectl apply -f istio/ingress/gateway.yaml
kubectl apply -f istio/ingress/virtualservice.yaml
echo ""


echo "📋 Apply ServiceEntry for external services (Dev environment)"
kubectl apply -f istio/se/external-services-se-dev.yaml
echo ""

echo "📋 Apply DestinationRules for external services (Dev environment)"
kubectl apply -f istio/dr/external-services-dr-dev.yaml
echo ""

echo "🔒 Apply PeerAuthentication STRICT policy"
kubectl apply -f istio/pa/pa-dev.yaml
echo ""


echo "🛺🛺 install istio addons 😆😆"
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

echo "🔌 install Kiali, Jaeger, Prometheus, Grafana NodePort"
cd istio-addon/nodeport
kubectl apply -f .
echo ""
cd ../..

echo ""
echo "✅✅✅ Dev Environment Setup Complete ✅✅✅"
echo ""
echo "Infrastructure (Docker Compose):"
echo "  - Redis:    localhost:26379"
echo "  - Kafka:    localhost:29092"
echo ""
echo "External Infrastructure (requires configuration):"
echo "  - MySQL:    (configured via mysql-config/mysql-secret)"
echo "  - MongoDB:  (configured via mongodb-config/mongodb-secret)"
echo ""
echo "Next steps:"
echo "  1. Deploy applications: cd ../dailyfeed-app-helm && source install-dev.sh <version>"
echo "  2. Check infrastructure: docker-compose -f docker/dev/docker-compose.yaml ps"
echo "  3. Check Kubernetes: kubectl get all -n dailyfeed"
echo ""
