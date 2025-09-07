#!/bin/bash

# MongoDB Installation Script for Dailyfeed
echo "=== MongoDB Installation Script ==="

# Bitnami 저장소 추가
echo "Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# MongoDB 설치
echo "Installing MongoDB..."
helm install mongodb bitnami/mongodb \
  --namespace infra \
  --create-namespace \
  --set auth.enabled=true \
  --set auth.rootUser="root" \
  --set auth.rootPassword="hitEnter###" \
  --set auth.username="dailyfeed" \
  --set auth.password="hitEnter###" \
  --set auth.database="dailyfeed" \
  --set persistence.enabled=true \
  --set persistence.size=1Gi \
  --set service.port=27017 \
  --set service.type=ClusterIP

# MongoDB Pod가 Ready 상태가 될 때까지 대기
echo "Waiting for MongoDB pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mongodb -n infra --timeout=180s

# 설치 상태 확인
echo ""
echo "=== MongoDB Installation Status ==="
kubectl get pods -n infra | grep mongodb
kubectl get svc -n infra | grep mongodb

echo ""
echo "=== MongoDB Connection Information ==="
echo "Service: mongodb.infra.svc.cluster.local"
echo "Port: 27017"
echo "Database: dailyfeed"
echo "Username: dailyfeed"
echo "Password: hitEnter###"
echo "Root Username: root"
echo "Root Password: hitEnter###"
echo ""
echo "Connection URI: mongodb://dailyfeed:hitEnter###@mongodb.infra.svc.cluster.local:27017/dailyfeed"
echo ""
echo "MongoDB installation completed!"