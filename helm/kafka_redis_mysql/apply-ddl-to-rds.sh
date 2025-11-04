#!/bin/bash

# RDS 연결 정보
RDS_HOST="dailyfeed-dev.c7muo0wa2dr1.ap-northeast-2.rds.amazonaws.com"
RDS_USER="dailyfeed"
RDS_PASSWORD="hitEnter###"
RDS_DATABASE="dailyfeed"

echo "📋 Applying DDL to RDS..."
echo "   Host: ${RDS_HOST}"
echo "   Database: ${RDS_DATABASE}"
echo ""

# MySQL 클라이언트 Pod를 임시로 생성하여 DDL 적용
kubectl run mysql-client-temp --image=mysql:8.0 -n infra --rm -i --restart=Never -- bash -c "
mysql -h ${RDS_HOST} -u ${RDS_USER} -p${RDS_PASSWORD} ${RDS_DATABASE} <<'EOFDDL'
$(cat ddl.sql)
EOFDDL
"

if [ $? -eq 0 ]; then
  echo "✅ DDL applied successfully to RDS"
else
  echo "❌ Failed to apply DDL to RDS"
  exit 1
fi

echo ""
echo "📋 Applying Spring Batch schema to RDS..."

kubectl run mysql-client-temp --image=mysql:8.0 -n infra --rm -i --restart=Never -- bash -c "
mysql -h ${RDS_HOST} -u ${RDS_USER} -p${RDS_PASSWORD} ${RDS_DATABASE} <<'EOFBATCH'
$(cat batch-schema.sql)
EOFBATCH
"

if [ $? -eq 0 ]; then
  echo "✅ Spring Batch schema applied successfully to RDS"
else
  echo "❌ Failed to apply Spring Batch schema to RDS"
  exit 1
fi

echo ""
echo "✅ All database schemas applied successfully!"
