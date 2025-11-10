#!/bin/bash

echo "Restoring original replica set configuration..."

mongosh "mongodb://root:hitEnter%21%21%21@localhost:27017/admin?directConnection=true" --eval '
var config = rs.conf();
config.members[0].host = "mongo_dailyfeed_1:27017";
config.members[1].host = "mongo_dailyfeed_2:27017";
config.members[2].host = "mongo_dailyfeed_3:27017";
rs.reconfig(config, {force: true});
'

echo "Waiting for reconfiguration to complete..."
sleep 5

echo "Checking restored configuration..."
mongosh "mongodb://root:hitEnter%21%21%21@localhost:27017/admin?directConnection=true" --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'

echo "Replica set configuration restored!"