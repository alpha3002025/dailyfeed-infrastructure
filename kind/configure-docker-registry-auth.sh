#!/bin/bash

# Configure Docker Registry Authentication for kind cluster
# This script creates a Kubernetes secret with Docker Hub credentials
# and configures the default service account to use it for image pulls.

set -e

NAMESPACE=${1:-"infra"}

echo "🔐 Configuring Docker Registry Authentication for namespace: $NAMESPACE"
echo ""

# Check if Docker is logged in
echo "📋 Checking Docker login status..."
if ! docker info | grep -q "Username:"; then
    echo "⚠️  Warning: Docker is not logged in or running in unauthenticated mode"
    echo "   Run 'docker login' first to authenticate with Docker Hub"
    echo ""
    read -p "Do you want to login now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker login
    else
        echo "❌ Aborted. Please login to Docker Hub first."
        exit 1
    fi
fi

echo "✅ Docker is logged in"
echo ""

# Create namespace if it doesn't exist
echo "📦 Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Delete existing secret if it exists
echo "🗑️  Removing existing regcred secret if it exists..."
kubectl delete secret regcred -n $NAMESPACE --ignore-not-found=true
echo "✅ Cleanup complete"
echo ""

# Create Docker registry secret
echo "🔑 Creating Docker registry secret..."
kubectl create secret generic regcred \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson \
  -n $NAMESPACE

echo "✅ Secret 'regcred' created in namespace '$NAMESPACE'"
echo ""

# Patch service account to use the secret
echo "🔧 Patching default service account with imagePullSecrets..."
kubectl patch serviceaccount default -n $NAMESPACE \
  -p '{"imagePullSecrets": [{"name": "regcred"}]}'

echo "✅ Service account patched"
echo ""

# Verify configuration
echo "🔍 Verifying configuration..."
kubectl get secret regcred -n $NAMESPACE > /dev/null 2>&1 && echo "  ✓ Secret exists"
kubectl get serviceaccount default -n $NAMESPACE -o yaml | grep -q "regcred" && echo "  ✓ Service account configured"
echo ""

echo "✨ Docker registry authentication configured successfully!"
echo ""
echo "💡 If you have pods in ImagePullBackOff state, delete them to trigger recreation:"
echo "   kubectl get pods -n $NAMESPACE | grep ImagePullBackOff | awk '{print \$1}' | xargs -r kubectl delete pod -n $NAMESPACE"
echo ""
