#!/bin/bash

# Bitnami 저장소 추가 (이미 있으면 스킵)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# MongoDB 설치 (ARM64 호환 이미지 사용)
helm install mongodb bitnami/mongodb \
  --namespace infra \
  --set auth.enabled=true \
  --set auth.rootUser="root" \
  --set auth.rootPassword="hitEnter@@@" \
  --set auth.database="dailyfeed" \
  --set auth.username="dailyfeed" \
  --set auth.password="hitEnter@@@" \
  --set service.port=27017 \
  --set image.tag="7.0.18-debian-12-r2"

# MongoDB Pod가 Ready 상태가 될 때까지 대기
echo "Waiting for MongoDB pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mongodb -n infra --timeout=180s

echo "MongoDB installation completed!"

# MongoDB Secret 생성 (infra namespace용)
kubectl create secret generic mongodb \
  --from-literal=mongo-uri="mongodb://dailyfeed:hitEnter@@@mongodb.infra.svc.cluster.local:27017/dailyfeed" \
  --namespace infra --dry-run=client -o yaml | kubectl apply -f -

echo "MongoDB secret created in infra namespace!"