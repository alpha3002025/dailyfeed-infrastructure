#!/bin/bash

# MongoDB User Initialization Script for Dailyfeed
# This script manually initializes MongoDB users when the container's
# docker-entrypoint-initdb.d mechanism is bypassed by custom command

echo "=== MongoDB User Initialization Script ==="

# Wait for MongoDB pod to be ready
echo "Waiting for MongoDB pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mongodb -n infra --timeout=60s

if [ $? -ne 0 ]; then
  echo "ERROR: MongoDB pod is not ready"
  exit 1
fi

# Get MongoDB pod name
MONGODB_POD=$(kubectl get pod -n infra -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')
echo "MongoDB pod: $MONGODB_POD"

# Check if users already exist
echo "Checking if users already exist..."
USER_COUNT=$(kubectl exec -n infra $MONGODB_POD -- mongosh dailyfeed --quiet --eval "db.getUsers().users.length" 2>/dev/null || echo "0")

if [ "$USER_COUNT" != "0" ]; then
  echo "Users already exist. Skipping initialization."
  exit 0
fi

# Create MongoDB users
echo "Creating MongoDB users..."
kubectl exec -n infra $MONGODB_POD -- mongosh dailyfeed --quiet --eval '
db.createUser({
  user: "dailyfeed",
  pwd: "hitEnter###",
  roles: [
    { role: "readWrite", db: "dailyfeed" },
    { role: "dbAdmin", db: "dailyfeed" }
  ]
});
db.createUser({
  user: "dailyfeed-search",
  pwd: "hitEnter###",
  roles: [
    { role: "readWrite", db: "dailyfeed" },
    { role: "dbAdmin", db: "dailyfeed" }
  ]
});
print("Users created successfully");
'

if [ $? -eq 0 ]; then
  echo ""
  echo "=== MongoDB Users Created Successfully ==="
  echo "Database: dailyfeed"
  echo "Users:"
  echo "  - dailyfeed (readWrite, dbAdmin)"
  echo "  - dailyfeed-search (readWrite, dbAdmin)"
  echo ""

  # Verify users
  echo "Verifying users..."
  kubectl exec -n infra $MONGODB_POD -- mongosh dailyfeed --quiet --eval "db.getUsers()"
else
  echo "ERROR: Failed to create MongoDB users"
  exit 1
fi

echo ""
echo "MongoDB user initialization completed!"
