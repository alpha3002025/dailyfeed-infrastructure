#!/bin/bash

echo "🔧 Adding custom DNS entries for infrastructure services to CoreDNS (Dev environment)..."

# Get container IPs from the Kind network dynamically
echo "📡 Detecting infrastructure service IPs on Kind network..."

KAFKA_1_IP=$(docker network inspect kind --format '{{range .Containers}}{{if eq .Name "kafka-1"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)
KAFKA_2_IP=$(docker network inspect kind --format '{{range .Containers}}{{if eq .Name "kafka-2"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)
KAFKA_3_IP=$(docker network inspect kind --format '{{range .Containers}}{{if eq .Name "kafka-3"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)

REDIS_IP=$(docker network inspect kind --format '{{range .Containers}}{{if eq .Name "redis-dailyfeed"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)

# Validate that we got Kafka and Redis IPs (MongoDB and MySQL are external in dev)
if [ -z "$KAFKA_1_IP" ] || [ -z "$KAFKA_2_IP" ] || [ -z "$KAFKA_3_IP" ] || [ -z "$REDIS_IP" ]; then
    echo "❌ Error: Could not detect all infrastructure service IPs"
    echo "   Make sure Docker Compose services are connected to the Kind network"
    echo "   Detected IPs:"
    echo "     Kafka-1: $KAFKA_1_IP"
    echo "     Kafka-2: $KAFKA_2_IP"
    echo "     Kafka-3: $KAFKA_3_IP"
    echo "     Redis: $REDIS_IP"
    echo "   Note: MongoDB and MySQL are external in dev environment"
    return 1
fi

echo "✅ Detected infrastructure IPs:"
echo "   Kafka-1:    $KAFKA_1_IP"
echo "   Kafka-2:    $KAFKA_2_IP"
echo "   Kafka-3:    $KAFKA_3_IP"
echo "   Redis:      $REDIS_IP"
echo "   (MongoDB and MySQL use external addresses configured in secrets)"
echo ""

# Get current CoreDNS ConfigMap
echo "📝 Backing up current CoreDNS ConfigMap..."
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml

# Create custom DNS entries
echo "🔨 Creating custom DNS entries..."

# Create new Corefile with custom hosts block
cat > /tmp/coredns-corefile.txt <<EOF
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
    # Custom DNS for infrastructure services (Dev environment)
    # Only Kafka and Redis (MongoDB and MySQL are external)
    hosts {
        $KAFKA_1_IP kafka-1
        $KAFKA_2_IP kafka-2
        $KAFKA_3_IP kafka-3
        $REDIS_IP redis-dailyfeed
        fallthrough
    }
}
EOF

# Apply the new ConfigMap
echo "📤 Applying updated CoreDNS ConfigMap..."
kubectl create configmap coredns -n kube-system --from-file=Corefile=/tmp/coredns-corefile.txt --dry-run=client -o yaml | kubectl apply -f -

# Force CoreDNS pods to reload
echo "🔄 Restarting CoreDNS pods to apply changes..."
kubectl rollout restart deployment coredns -n kube-system

# Wait for CoreDNS to be ready
echo "⏳ Waiting for CoreDNS pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s

if [ $? -eq 0 ]; then
    echo "✅ CoreDNS custom DNS entries added successfully"
    echo ""
    echo "DNS mappings added:"
    echo "  kafka-1          -> $KAFKA_1_IP"
    echo "  kafka-2          -> $KAFKA_2_IP"
    echo "  kafka-3          -> $KAFKA_3_IP"
    echo "  redis-dailyfeed  -> $REDIS_IP"
    echo ""
    echo "Backup saved to: /tmp/coredns-backup.yaml"
else
    echo "⚠️  CoreDNS is not ready yet"
    echo "   You can check status with: kubectl get pods -n kube-system -l k8s-app=kube-dns"
    echo "   Backup saved to: /tmp/coredns-backup.yaml"
    return 1
fi
