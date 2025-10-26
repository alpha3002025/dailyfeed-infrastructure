#!/bin/bash

echo "🔍 Verifying HPA (Horizontal Pod Autoscaler) Readiness"
echo "=================================================="
echo ""

# 1. metrics-server 상태 확인
echo "1️⃣ Checking metrics-server deployment status..."
METRICS_SERVER_STATUS=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)

if [ "$METRICS_SERVER_STATUS" = "True" ]; then
  echo "   ✅ metrics-server is running"
else
  echo "   ❌ metrics-server is not ready"
  echo ""
  kubectl get deployment metrics-server -n kube-system
  exit 1
fi
echo ""

# 2. metrics-server pod 상태 확인
echo "2️⃣ Checking metrics-server pods..."
kubectl get pods -n kube-system -l k8s-app=metrics-server
echo ""

# 3. Node metrics 확인
echo "3️⃣ Checking if node metrics are available..."
if kubectl top nodes &>/dev/null; then
  echo "   ✅ Node metrics are available"
  kubectl top nodes
else
  echo "   ⚠️  Node metrics not yet available (may need to wait ~1 minute)"
fi
echo ""

# 4. Pod metrics 확인
echo "4️⃣ Checking if pod metrics are available..."
if kubectl top pods -n dailyfeed &>/dev/null; then
  echo "   ✅ Pod metrics are available in 'dailyfeed' namespace"
  kubectl top pods -n dailyfeed
else
  echo "   ⚠️  Pod metrics not yet available (may need pods running and wait ~1 minute)"
fi
echo ""

# 5. HPA 샘플 YAML 생성
echo "5️⃣ Creating sample HPA configuration..."
cat > /tmp/sample-hpa.yaml <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sample-hpa
  namespace: dailyfeed
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: YOUR_DEPLOYMENT_NAME  # 실제 deployment 이름으로 변경 필요
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Max
EOF

echo "   ✅ Sample HPA configuration created at: /tmp/sample-hpa.yaml"
echo ""

# 6. HPA 사용 가이드
echo "📚 HPA Usage Guide"
echo "=================================================="
echo ""
echo "To create HPA for your deployment:"
echo "  1. Edit /tmp/sample-hpa.yaml and change 'YOUR_DEPLOYMENT_NAME'"
echo "  2. kubectl apply -f /tmp/sample-hpa.yaml"
echo ""
echo "To check HPA status:"
echo "  kubectl get hpa -n dailyfeed"
echo "  kubectl describe hpa <hpa-name> -n dailyfeed"
echo ""
echo "To test autoscaling:"
echo "  # Generate load on your pods"
echo "  kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh"
echo "  # Then run: while true; do wget -q -O- http://your-service; done"
echo ""
echo "Monitor autoscaling:"
echo "  watch kubectl get hpa -n dailyfeed"
echo ""

# 7. 최종 상태 요약
echo "=================================================="
if [ "$METRICS_SERVER_STATUS" = "True" ]; then
  echo "🎉 System is ready for HPA!"
else
  echo "⚠️  Please check the errors above"
fi
echo "=================================================="
