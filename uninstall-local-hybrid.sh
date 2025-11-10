#!/bin/bash

echo "🗑️🗑️🗑️ Hybrid Infrastructure Cleanup 🗑️🗑️🗑️"
echo ""

echo "=== Step 1: Delete Kind Cluster ==="
kind delete cluster --name istio-cluster
echo ""

echo "=== Step 2: Stop Docker Compose Infrastructure ==="
cd docker/local-hybrid
docker-compose down -v
echo ""

echo "Checking Docker Compose cleanup..."
docker-compose ps
echo ""

cd ../..

echo ""
echo "✅✅✅ Hybrid Infrastructure Cleanup Complete ✅✅✅"
echo ""
