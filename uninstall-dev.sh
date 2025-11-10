#!/bin/bash

echo "🗑️🗑️🗑️ Dev Environment Cleanup 🗑️🗑️🗑️"
echo ""

echo "=== Step 1: Delete Kind Cluster ==="
kind delete cluster --name istio-cluster
echo ""

echo "=== Step 2: Stop Docker Compose Infrastructure (Redis, Kafka) ==="
cd docker/dev
docker-compose down -v
echo ""

echo "Checking Docker Compose cleanup..."
docker-compose ps
echo ""

cd ../..

echo ""
echo "✅✅✅ Dev Environment Cleanup Complete ✅✅✅"
echo ""