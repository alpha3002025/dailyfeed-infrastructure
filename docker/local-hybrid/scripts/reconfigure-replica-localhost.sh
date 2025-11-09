#!/bin/bash

echo "Reconfiguring replica set with localhost addresses..."

mongosh "mongodb://root:hitEnter%21%21%21@localhost:27017/admin?directConnection=true" --eval '
var config = rs.conf();
config.members[0].host = "localhost:27017";
config.members[1].host = "localhost:27018";
config.members[2].host = "localhost:27019";
rs.reconfig(config, {force: true});
'

echo "Waiting for reconfiguration to complete..."
sleep 5

echo "Checking new configuration..."
mongosh "mongodb://root:hitEnter%21%21%21@localhost:27017/admin?directConnection=true" --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'

echo "Replica set reconfigured successfully!"