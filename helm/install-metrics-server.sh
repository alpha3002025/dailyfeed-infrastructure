#!/bin/bash

echo "📊📊📊 Installing metrics-server for HPA support"

# metrics-server 설치 (Kind 클러스터용 설정 포함)
# --kubelet-insecure-tls: Kind는 자체 서명된 인증서를 사용하므로 필요
# --kubelet-preferred-address-types: Kind 환경에서 내부 IP를 사용하도록 설정

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "⚙️ Patching metrics-server deployment for Kind cluster compatibility..."

# Kind 클러스터에서 작동하도록 metrics-server 패치
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  }
]'

echo ""
echo "⏳ Waiting for metrics-server to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

echo ""
echo "✅ Metrics-server installation completed!"
echo ""

# 설치 확인
echo "📋 Checking metrics-server status:"
kubectl get deployment metrics-server -n kube-system
echo ""

echo "📋 Metrics-server pods:"
kubectl get pods -n kube-system -l k8s-app=metrics-server
echo ""

echo "ℹ️  To verify metrics collection, wait ~1 minute then run:"
echo "   kubectl top nodes"
echo "   kubectl top pods -n dailyfeed"
echo ""
