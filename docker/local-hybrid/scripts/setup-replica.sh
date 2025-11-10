#!/bin/bash

echo "Waiting for MongoDB nodes to be ready..."
sleep 10

echo "Initializing replica set..."
mongosh --host mongo_dailyfeed_1:27017 <<EOF
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo_dailyfeed_1:27017", priority: 2 },
    { _id: 1, host: "mongo_dailyfeed_2:27017", priority: 1 },
    { _id: 2, host: "mongo_dailyfeed_3:27017", priority: 1 }
  ]
})
EOF

echo "Waiting for replica set to be initialized..."
sleep 10

echo "Creating users..."
mongosh --host mongo_dailyfeed_1:27017 <<EOF
use admin
db.createUser({
  user: "root",
  pwd: "hitEnter!!!",
  roles: [{ role: "root", db: "admin" }]
})

use dailyfeed
db.createUser({
  user: "dailyfeed-search",
  pwd: "hitEnter!!!",
  roles: [{ role: "readWrite", db: "dailyfeed" }]
})

db.createUser({
  user: "dailyfeed-svc",
  pwd: "hitEnter!!!",
  roles: [{ role: "read", db: "dailyfeed" }]
})
EOF

echo "Replica set setup complete!"