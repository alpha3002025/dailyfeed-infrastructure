#!/bin/bash

echo "🔧 Patching Control Plane component resource limits..."
echo ""

# control-plane 노드 이름 가져오기
CONTROL_PLANE_NODE=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')

if [ -z "$CONTROL_PLANE_NODE" ]; then
  echo "❌ Control plane node not found"
  exit 1
fi

echo "📍 Control plane node: $CONTROL_PLANE_NODE"
echo ""

# 각 컴포넌트의 manifest 파일 경로
MANIFEST_PATH="/etc/kubernetes/manifests"

#echo "=== Patching kube-apiserver ==="
#docker exec $CONTROL_PLANE_NODE bash -c "
#sed -i '/    - kube-apiserver/a\    resources:\n      requests:\n        cpu: 250m\n        memory: 512Mi\n      limits:\n        memory: 1Gi' $MANIFEST_PATH/kube-apiserver.yaml 2>/dev/null || \
#sed -i 's/memory: [0-9]*Mi/memory: 1Gi/g' $MANIFEST_PATH/kube-apiserver.yaml
#"
#echo "✅ kube-apiserver patched (memory limit: 1Gi, request: 512Mi)"
#echo ""

echo "=== Patching etcd ==="
docker exec $CONTROL_PLANE_NODE bash -c "
sed -i '/    - etcd/a\    resources:\n      requests:\n        cpu: 100m\n        memory: 256Mi\n      limits:\n        memory: 512Mi' $MANIFEST_PATH/etcd.yaml 2>/dev/null || \
sed -i 's/memory: [0-9]*Mi/memory: 512Mi/g' $MANIFEST_PATH/etcd.yaml
"
echo "✅ etcd patched (memory limit: 512Mi, request: 256Mi)"
echo ""

echo "=== Patching kube-controller-manager ==="
docker exec $CONTROL_PLANE_NODE bash -c "
sed -i '/    - kube-controller-manager/a\    resources:\n      requests:\n        cpu: 200m\n        memory: 256Mi\n      limits:\n        memory: 512Mi' $MANIFEST_PATH/kube-controller-manager.yaml 2>/dev/null || \
sed -i 's/memory: [0-9]*Mi/memory: 512Mi/g' $MANIFEST_PATH/kube-controller-manager.yaml
"
echo "✅ kube-controller-manager patched (memory limit: 512Mi, request: 256Mi)"
echo ""

echo "=== Patching kube-scheduler ==="
docker exec $CONTROL_PLANE_NODE bash -c "
sed -i '/    - kube-scheduler/a\    resources:\n      requests:\n        cpu: 100m\n        memory: 128Mi\n      limits:\n        memory: 256Mi' $MANIFEST_PATH/kube-scheduler.yaml 2>/dev/null || \
sed -i 's/memory: [0-9]*Mi/memory: 256Mi/g' $MANIFEST_PATH/kube-scheduler.yaml
"
echo "✅ kube-scheduler patched (memory limit: 256Mi, request: 128Mi)"
echo ""

echo "⏳ Waiting for control plane components to restart..."
echo "   (Static Pods will automatically restart when manifest files are modified)"
echo ""

# etcd 수정으로 인해 API server도 재시작됨, 충분한 시간 대기
echo "⏳ Waiting 20 seconds for components to begin restart..."
sleep 20

# API server가 다시 응답할 때까지 대기 (더 긴 timeout)
echo "⏳ Waiting for API server to be ready..."
RETRY_COUNT=0
MAX_RETRIES=60  # 2분 대기
until kubectl get --raw /healthz &>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
    echo "   Attempt $((RETRY_COUNT+1))/$MAX_RETRIES: API server not ready yet..."
  fi
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "⚠️  API server did not become ready within expected time"
  echo "⚠️  Continuing anyway, but subsequent steps may fail"
else
  echo "✅ API server is ready (took $((RETRY_COUNT*2)) seconds)"
fi

# 모든 control plane pod가 Running 상태가 될 때까지 추가 대기
echo ""
echo "⏳ Waiting for all control plane pods to be Running..."
RETRY_COUNT=0
MAX_RETRIES=30
until [ $(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | grep -c "Running") -ge 3 ] || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
    RUNNING_COUNT=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "   Attempt $((RETRY_COUNT+1))/$MAX_RETRIES: $RUNNING_COUNT/3+ control plane pods running..."
  fi
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT+1))
done

echo ""
echo "🔍 Checking control plane component status..."
kubectl get pods -n kube-system 2>/dev/null | grep -E "kube-apiserver|etcd|kube-controller-manager|kube-scheduler" || echo "   (Components are still restarting...)"

echo ""
echo "✅ Control plane resource limits updated"
echo ""
echo "Summary:"
#echo "  - kube-apiserver:          memory 1Gi (request: 512Mi)"
echo "  - etcd:                    memory 512Mi (request: 256Mi)"
echo "  - kube-controller-manager: memory 512Mi (request: 256Mi)"
echo "  - kube-scheduler:          memory 256Mi (request: 128Mi)"
echo ""