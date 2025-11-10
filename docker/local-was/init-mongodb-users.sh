#!/bin/bash

echo "=== MongoDB User Initialization ==="

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
sleep 20

# Check if MongoDB is accessible
docker exec mongo-dailyfeed-1 mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: MongoDB is not ready yet. Please wait and try again."
  exit 1
fi

echo "MongoDB is ready. Creating users..."

# Create users in dailyfeed database
docker exec mongo-dailyfeed-1 mongosh --eval '
use dailyfeed;

// Check if users already exist
var existingUsers = db.getUsers();
if (existingUsers.users.length > 0) {
  print("Users already exist. Skipping creation.");
  quit(0);
}

// Create dailyfeed user
db.createUser({
  user: "dailyfeed",
  pwd: "hitEnter###",
  roles: [
    { role: "readWrite", db: "dailyfeed" },
    { role: "dbAdmin", db: "dailyfeed" }
  ]
});

// Create dailyfeed-search user
db.createUser({
  user: "dailyfeed-search",
  pwd: "hitEnter###",
  roles: [
    { role: "readWrite", db: "dailyfeed" },
    { role: "dbAdmin", db: "dailyfeed" }
  ]
});

print("✅ MongoDB users created successfully!");
print("Users:");
print("  - dailyfeed (readWrite, dbAdmin)");
print("  - dailyfeed-search (readWrite, dbAdmin)");
'

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ MongoDB user initialization completed!"
else
  echo ""
  echo "❌ MongoDB user initialization failed!"
  exit 1
fi
