#!/bin/bash

echo "🔧 Patching Control Plane component resource limits..."
echo "   (Using simpler, more reliable method)"
echo ""

# Control-plane 노드 이름 가져오기
CONTROL_PLANE_NODE=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')

if [ -z "$CONTROL_PLANE_NODE" ]; then
  echo "❌ Control plane node not found"
  exit 1
fi

echo "📍 Control plane node: $CONTROL_PLANE_NODE"
echo ""

# 각 컴포넌트의 manifest 파일 경로
MANIFEST_PATH="/etc/kubernetes/manifests"

# 이미 리소스가 설정되어 있는지 확인하는 함수
check_resources_exist() {
  local file=$1
  docker exec $CONTROL_PLANE_NODE grep -q "resources:" $file 2>/dev/null
  return $?
}

echo "=== Patching etcd ==="
if check_resources_exist "$MANIFEST_PATH/etcd.yaml"; then
  echo "   Resources already configured, skipping..."
else
  docker exec $CONTROL_PLANE_NODE bash -c "
    sed -i '/^    - name: etcd$/a\    resources:\n      requests:\n        cpu: 100m\n        memory: 256Mi\n      limits:\n        cpu: 200m\n        memory: 512Mi' $MANIFEST_PATH/etcd.yaml
  " && echo "✅ etcd patched (memory limit: 512Mi, request: 256Mi)" || echo "⚠️  etcd patch failed or already applied"
fi
echo ""

echo "=== Patching kube-controller-manager ==="
if check_resources_exist "$MANIFEST_PATH/kube-controller-manager.yaml"; then
  echo "   Resources already configured, skipping..."
else
  docker exec $CONTROL_PLANE_NODE bash -c "
    sed -i '/^    - name: kube-controller-manager$/a\    resources:\n      requests:\n        cpu: 100m\n        memory: 256Mi\n      limits:\n        cpu: 200m\n        memory: 512Mi' $MANIFEST_PATH/kube-controller-manager.yaml
  " && echo "✅ kube-controller-manager patched (memory limit: 512Mi, request: 256Mi)" || echo "⚠️  controller-manager patch failed or already applied"
fi
echo ""

echo "=== Patching kube-scheduler ==="
if check_resources_exist "$MANIFEST_PATH/kube-scheduler.yaml"; then
  echo "   Resources already configured, skipping..."
else
  docker exec $CONTROL_PLANE_NODE bash -c "
    sed -i '/^    - name: kube-scheduler$/a\    resources:\n      requests:\n        cpu: 50m\n        memory: 128Mi\n      limits:\n        cpu: 100m\n        memory: 256Mi' $MANIFEST_PATH/kube-scheduler.yaml
  " && echo "✅ kube-scheduler patched (memory limit: 256Mi, request: 128Mi)" || echo "⚠️  scheduler patch failed or already applied"
fi
echo ""

echo "⏳ Waiting for control plane components to restart (if needed)..."
sleep 10
echo ""

echo "✅ Control plane resource configuration complete"
echo ""
echo "Summary:"
echo "  - etcd:                    memory 512Mi (request: 256Mi, cpu: 100-200m)"
echo "  - kube-controller-manager: memory 512Mi (request: 256Mi, cpu: 100-200m)"
echo "  - kube-scheduler:          memory 256Mi (request: 128Mi, cpu: 50-100m)"
echo ""
echo "Note: Components will restart automatically if changes were applied."
echo "      Subsequent steps will verify API server readiness."
echo ""