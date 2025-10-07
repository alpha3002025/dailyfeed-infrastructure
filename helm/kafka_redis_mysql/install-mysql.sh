# WSO2 저장소 추가
helm repo add wso2 https://helm.wso2.com
helm repo update

# MySQL 설치
helm install mysql wso2/mysql \
  --namespace infra \
  --set mysqlRootPassword="hitEnter###" \
  --set mysqlUser="dailyfeed" \
  --set mysqlPassword="hitEnter###" \
  --set mysqlDatabase="dailyfeed" \
  --set image="mysql" \
  --set imageTag="8.0" \
  --set persistence.enabled=false \
  --set resources.requests.memory="256Mi" \
  --set resources.requests.cpu="250m" \
  --set resources.limits.memory="512Mi" \
  --set resources.limits.cpu="500m"

# MySQL Pod 상태 확인
echo "Waiting for MySQL pod to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql -n infra --timeout=300s

# DDL 적용
if [ $? -eq 0 ]; then
  echo "✓ MySQL is ready. Applying DDL..."
  MYSQL_POD=$(kubectl get pod -n infra -l app=mysql -o jsonpath='{.items[0].metadata.name}')
  kubectl cp ./ddl.sql infra/$MYSQL_POD:/tmp/ddl.sql
  kubectl exec -n infra $MYSQL_POD -- mysql -udailyfeed -phitEnter### dailyfeed -e "source /tmp/ddl.sql"
  echo "✓ DDL execution completed successfully!"
else
  echo "✗ MySQL pod failed to start. Checking logs..."
  kubectl logs -l app=mysql -n infra --tail=50
  exit 1
fi
