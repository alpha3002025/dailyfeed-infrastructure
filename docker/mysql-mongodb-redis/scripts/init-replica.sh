#!/bin/bash

echo "Waiting for MongoDB nodes to be ready..."
sleep 15

echo "Initializing replica set..."
mongosh --host mongo_dailyfeed_1:27017 --eval '
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo_dailyfeed_1:27017", priority: 2 },
    { _id: 1, host: "mongo_dailyfeed_2:27017", priority: 1 },
    { _id: 2, host: "mongo_dailyfeed_3:27017", priority: 1 }
  ]
})'

echo "Waiting for PRIMARY to be elected..."
sleep 20

echo "Creating admin user on PRIMARY..."
mongosh --host mongo_dailyfeed_1:27017 --eval '
db = db.getSiblingDB("admin");
db.createUser({
  user: "root",
  pwd: "hitEnter!!!",
  roles: [{ role: "root", db: "admin" }]
});'

echo "Authenticating and creating application users..."
mongosh --host mongo_dailyfeed_1:27017 -u root -p 'hitEnter!!!' --authenticationDatabase admin --eval '
db = db.getSiblingDB("dailyfeed");
db.createUser({
  user: "dailyfeed-search",
  pwd: "hitEnter!!!",
  roles: [{ role: "readWrite", db: "dailyfeed" }]
});

db.createUser({
  user: "dailyfeed-svc",
  pwd: "hitEnter!!!",
  roles: [{ role: "read", db: "dailyfeed" }]
});

print("Users created successfully!");'

echo "Replica set initialization complete!"