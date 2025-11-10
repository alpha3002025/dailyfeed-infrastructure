#!/bin/bash

echo "🔧 Patching CoreDNS resource limits..."

# CoreDNS 메모리 제한 증가 (170Mi -> 512Mi)
kubectl patch deployment coredns -n kube-system --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/memory",
    "value": "512Mi"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/memory",
    "value": "256Mi"
  }
]'

echo "✅ CoreDNS resource limits updated"
echo "   - Memory limit: 170Mi -> 512Mi"
echo "   - Memory request: 70Mi -> 256Mi"

# CoreDNS Pod가 재시작되고 Ready 상태가 될 때까지 대기
echo "⏳ Waiting for CoreDNS pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=coredns -n kube-system --timeout=120s

if [ $? -eq 0 ]; then
  echo "✅ CoreDNS is ready"
else
  echo "⚠️ CoreDNS is not ready yet, but continuing..."
fi
