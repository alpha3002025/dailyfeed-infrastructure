#!/bin/bash

# Zookeeper 배포
cat <<EOF | kubectl apply -n infra -f -
apiVersion: v1
kind: Service
metadata:
  name: zookeeper
  labels:
    app: zookeeper
spec:
  ports:
  - port: 2181
    name: client
  - port: 2888
    name: server
  - port: 3888
    name: leader-election
  clusterIP: None
  selector:
    app: zookeeper
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
spec:
  serviceName: zookeeper
  replicas: 3
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      # !!![docker hub pro]
      # imagePullSecrets:
      # - name: dockerhub-secret
      containers:
      - name: zookeeper
        image: confluentinc/cp-zookeeper:7.5.0
        ports:
        - containerPort: 2181
          name: client
        - containerPort: 2888
          name: server
        - containerPort: 3888
          name: leader-election
        command:
        - sh
        - -c
        - |
          export ZOOKEEPER_SERVER_ID=\$((1 + \${HOSTNAME##*-}))
          /etc/confluent/docker/run
        env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "2181"
        - name: ZOOKEEPER_TICK_TIME
          value: "2000"
        - name: ZOOKEEPER_SYNC_LIMIT
          value: "5"
        - name: ZOOKEEPER_INIT_LIMIT
          value: "10"
        - name: ZOOKEEPER_SERVERS
          value: "zookeeper-0.zookeeper.infra.svc.cluster.local:2888:3888;zookeeper-1.zookeeper.infra.svc.cluster.local:2888:3888;zookeeper-2.zookeeper.infra.svc.cluster.local:2888:3888"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
EOF

# Zookeeper 준비 대기
echo "Waiting for Zookeeper to be ready..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n infra --timeout=180s

# Kafka 배포
cat <<EOF | kubectl apply -n infra -f -
apiVersion: v1
kind: Service
metadata:
  name: kafka
  labels:
    app: kafka
spec:
  ports:
  - port: 9092
    name: client
  clusterIP: None
  selector:
    app: kafka
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  labels:
    app: kafka
spec:
  ports:
  - port: 9092
    name: client
  clusterIP: None
  selector:
    app: kafka
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
spec:
  serviceName: kafka-headless
  replicas: 3
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      # !!![docker hub pro]
      # imagePullSecrets:
      # - name: dockerhub-secret
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:7.5.0
        ports:
        - containerPort: 9092
          name: client
        command:
        - sh
        - -c
        - |
          export KAFKA_BROKER_ID=\${HOSTNAME##*-}
          export KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://\${HOSTNAME}.kafka-headless.infra.svc.cluster.local:9092
          /etc/confluent/docker/run
        env:
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper-0.zookeeper.infra.svc.cluster.local:2181,zookeeper-1.zookeeper.infra.svc.cluster.local:2181,zookeeper-2.zookeeper.infra.svc.cluster.local:2181"
        - name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
          value: "PLAINTEXT:PLAINTEXT"
        - name: KAFKA_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "3"
        - name: KAFKA_DEFAULT_REPLICATION_FACTOR
          value: "3"
        - name: KAFKA_MIN_INSYNC_REPLICAS
          value: "2"
        - name: KAFKA_AUTO_CREATE_TOPICS_ENABLE
          value: "true"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
EOF

# Kafka 준비 대기
echo "Waiting for Kafka to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka -n infra --timeout=300s

if [ $? -eq 0 ]; then
  echo "✓ Kafka installation completed successfully!"
  kubectl get pods -n infra -l app=kafka
else
  echo "✗ Kafka pods failed to start. Checking status..."
  kubectl get pods -n infra -l app=kafka
  kubectl describe pods -n infra -l app=kafka
  exit 1
fi
