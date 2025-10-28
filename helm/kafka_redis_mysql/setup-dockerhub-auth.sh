#!/bin/bash

# Docker Hub 인증 정보 설정 스크립트
# Pro 계정의 Rate Limit을 사용하기 위해 Kubernetes Secret 생성

echo "🔐 Setting up Docker Hub authentication..."

# 사용자 입력 받기
# read -p "Enter your Docker Hub username: " DOCKER_USERNAME
# read -sp "Enter your Docker Hub password or access token: " DOCKER_PASSWORD
# echo ""
# read -p "Enter your Docker Hub email: " DOCKER_EMAIL

# infra 네임스페이스가 없으면 생성
kubectl get namespace infra &> /dev/null
if [ $? -ne 0 ]; then
  echo "Creating namespace 'infra'..."
  kubectl create namespace infra
fi

# 기존 secret이 있으면 삭제
kubectl get secret dockerhub-secret -n infra &> /dev/null
if [ $? -eq 0 ]; then
  echo "Removing existing dockerhub-secret..."
  kubectl delete secret dockerhub-secret -n infra
fi

# Docker Hub Secret 생성
echo "Creating dockerhub-secret in infra namespace..."
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USERNAME" \
  --docker-password="$DOCKER_PASSWORD" \
  --docker-email="$DOCKER_EMAIL" \
  -n infra

if [ $? -eq 0 ]; then
  echo "✓ Docker Hub authentication secret created successfully!"
  echo ""
  echo "Next steps:"
  echo "1. Run: kubectl get secret dockerhub-secret -n infra"
  echo "2. The Redis and Kafka installation scripts will be updated to use this secret"
else
  echo "✗ Failed to create Docker Hub secret"
  exit 1
fi
