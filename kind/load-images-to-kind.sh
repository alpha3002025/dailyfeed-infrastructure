#!/bin/bash

# Docker 이미지를 로컬에 pull한 후 kind 클러스터로 로드하는 스크립트
# Docker Hub Rate Limit 문제 해결용

set -e

CLUSTER_NAME="istio-cluster"

echo "🐳 Pulling Docker images to local..."
echo ""

# Kafka 관련 이미지
echo "📦 Pulling Zookeeper image..."
docker pull confluentinc/cp-zookeeper:7.5.0

echo "📦 Pulling Kafka image..."
docker pull confluentinc/cp-kafka:7.5.0

# Database 이미지
echo "📦 Pulling MySQL image..."
docker pull mysql:8.0

# Utility 이미지
echo "📦 Pulling busybox image..."
docker pull busybox:1.32

echo ""
echo "✓ All images pulled successfully!"
echo ""

# kind 클러스터 확인
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "❌ Error: kind cluster '${CLUSTER_NAME}' not found"
  echo "Available clusters:"
  kind get clusters
  exit 1
fi

echo "🚀 Loading images to kind cluster '${CLUSTER_NAME}'..."
echo ""

echo "📦 Loading Zookeeper image..."
kind load docker-image confluentinc/cp-zookeeper:7.5.0 --name ${CLUSTER_NAME}

echo "📦 Loading Kafka image..."
kind load docker-image confluentinc/cp-kafka:7.5.0 --name ${CLUSTER_NAME}

echo "📦 Loading MySQL image..."
kind load docker-image mysql:8.0 --name ${CLUSTER_NAME}

echo "📦 Loading busybox image..."
kind load docker-image busybox:1.32 --name ${CLUSTER_NAME}

echo ""
echo "✓ All images loaded to kind cluster successfully!"
echo ""
echo "You can now run: ./local-install-infra-and-app.sh <version>"
