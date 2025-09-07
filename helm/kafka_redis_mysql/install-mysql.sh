# Bitnami 저장소 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# MySQL 설치 (initdbScriptsConfigMap 없이)
helm install mysql bitnami/mysql \
  --namespace infra \
  --set auth.rootPassword="hitEnter###" \
  --set auth.username="dailyfeed" \
  --set auth.password="hitEnter###" \
  --set auth.database="dailyfeed" \
  --set primary.service.ports.mysql=3306

# MySQL Pod가 Ready 상태가 될 때까지 대기
echo "Waiting for MySQL pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mysql -n infra --timeout=120s

# DDL 파일을 MySQL Pod로 복사
echo "Copying DDL file to MySQL pod..."
kubectl cp ddl.sql infra/mysql-0:/tmp/ddl.sql

# DDL 실행
echo "Executing DDL scripts..."
kubectl exec mysql-0 -n infra -- bash -c "mysql -uroot -p'hitEnter###' dailyfeed < /tmp/ddl.sql"

echo "MySQL installation and DDL execution completed!"
