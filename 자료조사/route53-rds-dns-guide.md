# DNS 기반 접근 (AWS Route53 Private Hosted Zone)

> RDS 엔드포인트가 매일 변경되어도 고정 DNS 이름으로 안정적으로 접속하는 방법

## 📋 목차

1. [개요](#개요)
2. [전체 아키텍처](#전체-아키텍처)
3. [구현 단계](#구현-단계)
   - [1단계: Private Hosted Zone 생성](#1단계-private-hosted-zone-생성)
   - [2단계: RDS 관리 스크립트 작성](#2단계-rds-관리-스크립트-작성)
   - [3단계: Kubernetes 설정](#3단계-kubernetes-설정)
   - [4단계: 애플리케이션 Deployment](#4단계-애플리케이션-deployment)
   - [5단계: DNS 동작 확인](#5단계-dns-동작-확인)
   - [6단계: 자동화 설정](#6단계-자동화-설정)
4. [전체 워크플로우](#전체-워크플로우)
5. [장점 및 주의사항](#장점-및-주의사항)

---

## 개요

**문제 상황:**
- Dev 환경 RDS가 매일 9시~18시 사이에 생성/삭제됨
- RDS 엔드포인트 주소가 매번 변경됨
- Kubernetes 애플리케이션이 변경된 주소를 자동으로 인식해야 함

**해결 방법:**
- Route53 Private Hosted Zone으로 고정 DNS 이름 제공
- RDS 생성 시 CNAME 레코드 자동 업데이트
- 애플리케이션은 고정 DNS만 참조하여 코드 변경 불필요

---

## 전체 아키텍처

```
┌─────────────────────┐
│  Kubernetes Pod     │
└──────────┬──────────┘
           │
           ↓
  dev-rds.internal.mycompany.com (고정 DNS)
           │
           ↓
┌─────────────────────────────────────┐
│  Route53 Private Hosted Zone        │
│  CNAME: dev-rds.internal...         │
│    → dev-rds.c1a2b3.rds.amazonaws... │
└──────────┬──────────────────────────┘
           │
           ↓
┌─────────────────────┐
│  RDS Instance       │
│  (매일 재생성)       │
└─────────────────────┘
```

**동작 원리:**
1. Kubernetes Pod는 `dev-rds.internal.mycompany.com` 접속
2. Route53이 실제 RDS 엔드포인트로 변환
3. RDS 재생성 시 CNAME 레코드만 자동 업데이트
4. 애플리케이션 코드/설정 변경 불필요

---

## 구현 단계

### 1단계: Private Hosted Zone 생성

#### VPC 정보 확인

```bash
# EKS 클러스터와 RDS가 사용하는 VPC ID 확인
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=your-vpc-name"

# 또는 EKS 클러스터에서 VPC ID 확인
aws eks describe-cluster --name your-cluster-name \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text
```

#### Private Hosted Zone 생성

```bash
# 환경 변수 설정
VPC_ID="vpc-0123456789abcdef"
REGION="ap-northeast-2"
DOMAIN="internal.mycompany.com"

# Private Hosted Zone 생성
aws route53 create-hosted-zone \
  --name $DOMAIN \
  --vpc VPCRegion=$REGION,VPCId=$VPC_ID \
  --caller-reference $(date +%s) \
  --hosted-zone-config Comment="Private zone for dev RDS",PrivateZone=true

# 생성된 Hosted Zone ID 확인
aws route53 list-hosted-zones-by-name \
  --dns-name $DOMAIN \
  --query 'HostedZones[0].[Id,Name]' \
  --output table
```

**출력 예시:**
```
-----------------------------------------------------
|           ListHostedZonesByName                   |
+---------------------------------------------------+
|  /hostedzone/Z08123456789ABCDEFGH                |
|  internal.mycompany.com.                         |
+---------------------------------------------------+
```

**중요:** Hosted Zone ID를 저장해두세요 (예: `Z08123456789ABCDEFGH`)

---

### 2단계: RDS 관리 스크립트 작성

#### 완전 자동화 스크립트

`manage-dev-rds.sh` 파일 생성:

```bash
#!/bin/bash
# manage-dev-rds.sh
# RDS 생성/삭제 및 DNS 자동 업데이트 스크립트

set -e

# ===== 설정 변수 (실제 환경에 맞게 수정) =====
RDS_INSTANCE_ID="dev-rds"
HOSTED_ZONE_ID="Z08123456789ABCDEFGH"  # 1단계에서 생성한 Zone ID
DNS_NAME="dev-rds.internal.mycompany.com"
DB_SUBNET_GROUP="your-db-subnet-group"
SECURITY_GROUP_ID="sg-0123456789abcdef"
DB_PASSWORD="YourSecurePassword123!"
REGION="ap-northeast-2"

# ===== 함수 정의 =====

function create_rds_and_update_dns() {
    echo "========================================="
    echo "RDS 인스턴스 생성 시작"
    echo "========================================="
    
    # 1. RDS 인스턴스 생성
    aws rds create-db-instance \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --db-instance-class db.t3.micro \
        --engine mysql \
        --engine-version 8.0 \
        --master-username admin \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --storage-type gp3 \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --db-subnet-group-name $DB_SUBNET_GROUP \
        --backup-retention-period 0 \
        --no-multi-az \
        --publicly-accessible false \
        --storage-encrypted \
        --deletion-protection false \
        --no-enable-cloudwatch-logs-exports \
        --region $REGION
    
    echo "RDS 생성 요청 완료. 인스턴스가 사용 가능할 때까지 대기 중..."
    
    # 2. RDS 인스턴스가 available 상태가 될 때까지 대기
    aws rds wait db-instance-available \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --region $REGION
    
    echo "✓ RDS 인스턴스가 사용 가능한 상태입니다."
    
    # 3. RDS 엔드포인트 주소 가져오기
    RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --region $REGION \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    
    echo "RDS 엔드포인트: $RDS_ENDPOINT"
    
    # 4. Route53 CNAME 레코드 생성/업데이트
    echo "Route53 DNS 레코드 업데이트 중..."
    
    cat > /tmp/change-batch-$$.json << EOF
{
  "Comment": "Update dev RDS endpoint",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$DNS_NAME",
      "Type": "CNAME",
      "TTL": 60,
      "ResourceRecords": [{"Value": "$RDS_ENDPOINT"}]
    }
  }]
}
EOF
    
    CHANGE_ID=$(aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file:///tmp/change-batch-$$.json \
        --query 'ChangeInfo.Id' \
        --output text)
    
    echo "DNS 변경 요청 ID: $CHANGE_ID"
    
    # 5. DNS 변경 완료 대기
    aws route53 wait resource-record-sets-changed --id $CHANGE_ID
    
    # 임시 파일 삭제
    rm -f /tmp/change-batch-$$.json
    
    echo "========================================="
    echo "✓ RDS 생성 및 DNS 업데이트 완료!"
    echo "DNS 이름: $DNS_NAME"
    echo "실제 엔드포인트: $RDS_ENDPOINT"
    echo "========================================="
}

function delete_rds() {
    echo "========================================="
    echo "RDS 인스턴스 삭제 시작"
    echo "========================================="
    
    # RDS 인스턴스 삭제 (스냅샷 없이)
    aws rds delete-db-instance \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --skip-final-snapshot \
        --delete-automated-backups \
        --region $REGION
    
    echo "RDS 삭제 요청 완료. 삭제가 완료될 때까지 대기 중..."
    
    # 삭제 완료 대기
    aws rds wait db-instance-deleted \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --region $REGION
    
    echo "========================================="
    echo "✓ RDS 인스턴스 삭제 완료!"
    echo "Note: DNS 레코드는 유지됩니다 (다음 생성 시 재사용)"
    echo "========================================="
}

function check_rds_status() {
    echo "========================================="
    echo "현재 상태 확인"
    echo "========================================="
    
    STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --region $REGION \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")
    
    if [ "$STATUS" = "not-found" ]; then
        echo "RDS 인스턴스: 존재하지 않음"
    else
        echo "RDS 상태: $STATUS"
        
        ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier $RDS_INSTANCE_ID \
            --region $REGION \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text 2>/dev/null || echo "N/A")
        
        echo "RDS 엔드포인트: $ENDPOINT"
    fi
    
    # DNS 레코드 확인
    DNS_VALUE=$(aws route53 list-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --query "ResourceRecordSets[?Name=='$DNS_NAME.'].ResourceRecords[0].Value" \
        --output text 2>/dev/null || echo "N/A")
    
    echo "DNS 레코드 ($DNS_NAME): $DNS_VALUE"
    echo "========================================="
}

# ===== 메인 실행 =====

case "${1:-}" in
    create)
        create_rds_and_update_dns
        ;;
    delete)
        delete_rds
        ;;
    status)
        check_rds_status
        ;;
    *)
        echo "사용법: $0 {create|delete|status}"
        echo ""
        echo "명령어:"
        echo "  create - RDS 생성 및 DNS 자동 업데이트"
        echo "  delete - RDS 삭제 (DNS 레코드는 유지)"
        echo "  status - 현재 RDS 및 DNS 상태 확인"
        echo ""
        echo "예시:"
        echo "  $0 create   # RDS 생성"
        echo "  $0 status   # 상태 확인"
        echo "  $0 delete   # RDS 삭제"
        exit 1
        ;;
esac
```

#### 스크립트 사용법

```bash
# 실행 권한 부여
chmod +x manage-dev-rds.sh

# RDS 생성 및 DNS 자동 업데이트
./manage-dev-rds.sh create

# 현재 상태 확인
./manage-dev-rds.sh status

# RDS 삭제
./manage-dev-rds.sh delete
```

---

### 3단계: Kubernetes 설정

#### ConfigMap 생성

고정된 DNS 이름을 사용하는 ConfigMap:

```yaml
# db-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: default
data:
  # 고정된 DNS 이름 - 절대 변경되지 않음
  DB_HOST: "dev-rds.internal.mycompany.com"
  DB_PORT: "3306"
  DB_NAME: "mydb"
```

#### Secret 생성

```yaml
# db-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: default
type: Opaque
stringData:
  DB_USER: "admin"
  DB_PASSWORD: "YourSecurePassword123!"
```

#### Kubernetes에 적용

```bash
kubectl apply -f db-config.yaml
kubectl apply -f db-secret.yaml

# 확인
kubectl get configmap db-config -o yaml
kubectl get secret db-secret
```

---

### 4단계: 애플리케이션 Deployment

#### Deployment 설정

```yaml
# app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        # ConfigMap에서 고정 DNS 이름 읽기
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: db-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: db-config
              key: DB_PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: db-config
              key: DB_NAME
        
        # Secret에서 자격증명 읽기
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD
        
        # 연결 문자열 구성 (애플리케이션에 따라 다름)
        - name: DATABASE_URL
          value: "mysql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
        
        ports:
        - containerPort: 8080
        
        # 헬스체크 설정 (옵션)
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

#### 애플리케이션 배포

```bash
kubectl apply -f app-deployment.yaml

# 배포 상태 확인
kubectl rollout status deployment/myapp

# Pod 확인
kubectl get pods -l app=myapp
```

---

### 5단계: DNS 동작 확인

#### Kubernetes Pod 내부에서 DNS 테스트

```bash
# 임시 디버그 Pod 실행
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Pod 내부에서 DNS 조회
nslookup dev-rds.internal.mycompany.com
```

**예상 결과:**
```
Server:    10.100.0.10
Address 1: 10.100.0.10 kube-dns.kube-system.svc.cluster.local

Name:      dev-rds.internal.mycompany.com
Address 1: 172.31.10.123 dev-rds.c1a2b3c4d5e6.ap-northeast-2.rds.amazonaws.com
```

#### MySQL 연결 테스트

```bash
# MySQL 클라이언트로 테스트
kubectl run -it --rm mysql-client --image=mysql:8.0 --restart=Never -- \
  mysql -h dev-rds.internal.mycompany.com \
        -u admin \
        -p \
        -D mydb
```

#### 애플리케이션 로그 확인

```bash
# 로그 확인
kubectl logs -f deployment/myapp

# 특정 Pod 로그
kubectl logs -f myapp-xxxxx-yyyyy

# 모든 Pod 로그 동시 확인
kubectl logs -f -l app=myapp --max-log-requests=10
```

---

### 6단계: 자동화 설정

#### 옵션 1: Linux Cron (단순한 환경)

```bash
# crontab 편집
crontab -e

# 평일 오전 9시 KST에 RDS 생성 (UTC 00:00)
0 0 * * 1-5 /path/to/manage-dev-rds.sh create >> /var/log/rds-create.log 2>&1

# 평일 오후 6시 KST에 RDS 삭제 (UTC 09:00)
0 9 * * 1-5 /path/to/manage-dev-rds.sh delete >> /var/log/rds-delete.log 2>&1

# 로그 로테이션 설정 (옵션)
0 0 * * 0 find /var/log/rds-*.log -mtime +30 -delete
```

**참고:** KST는 UTC+9이므로 시간 변환 필요
- KST 09:00 = UTC 00:00
- KST 18:00 = UTC 09:00

#### 옵션 2: AWS Lambda + EventBridge (권장)

**Lambda 함수 생성:**

`lambda_function.py`:

```python
import boto3
import os
import json

rds = boto3.client('rds', region_name='ap-northeast-2')
route53 = boto3.client('route53')

def lambda_handler(event, context):
    """
    RDS 생성/삭제 및 DNS 업데이트 Lambda 함수
    
    event 예시:
    {
        "action": "create" or "delete"
    }
    """
    
    action = event.get('action')
    
    # 환경 변수에서 설정 읽기
    db_instance_id = os.environ['DB_INSTANCE_ID']
    hosted_zone_id = os.environ['HOSTED_ZONE_ID']
    dns_name = os.environ['DNS_NAME']
    
    try:
        if action == 'create':
            return create_rds_and_update_dns(
                db_instance_id, 
                hosted_zone_id, 
                dns_name
            )
        elif action == 'delete':
            return delete_rds(db_instance_id)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid action. Use "create" or "delete"')
            }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def create_rds_and_update_dns(db_instance_id, hosted_zone_id, dns_name):
    print(f"Creating RDS instance: {db_instance_id}")
    
    # 1. RDS 생성
    rds.create_db_instance(
        DBInstanceIdentifier=db_instance_id,
        DBInstanceClass='db.t3.micro',
        Engine='mysql',
        EngineVersion='8.0',
        MasterUsername='admin',
        MasterUserPassword=os.environ['DB_PASSWORD'],
        AllocatedStorage=20,
        StorageType='gp3',
        VpcSecurityGroupIds=[os.environ['SECURITY_GROUP_ID']],
        DBSubnetGroupName=os.environ['DB_SUBNET_GROUP'],
        BackupRetentionPeriod=0,
        MultiAZ=False,
        PubliclyAccessible=False,
        StorageEncrypted=True,
        DeletionProtection=False
    )
    
    # 2. RDS available 상태 대기
    print("Waiting for RDS to become available...")
    waiter = rds.get_waiter('db_instance_available')
    waiter.wait(
        DBInstanceIdentifier=db_instance_id,
        WaiterConfig={
            'Delay': 30,
            'MaxAttempts': 40
        }
    )
    
    # 3. 엔드포인트 가져오기
    response = rds.describe_db_instances(
        DBInstanceIdentifier=db_instance_id
    )
    endpoint = response['DBInstances'][0]['Endpoint']['Address']
    
    print(f"RDS endpoint: {endpoint}")
    
    # 4. Route53 DNS 업데이트
    route53.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch={
            'Comment': 'Update dev RDS endpoint',
            'Changes': [{
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': dns_name,
                    'Type': 'CNAME',
                    'TTL': 60,
                    'ResourceRecords': [{'Value': endpoint}]
                }
            }]
        }
    )
    
    print(f"DNS updated: {dns_name} -> {endpoint}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'RDS created and DNS updated successfully',
            'endpoint': endpoint,
            'dns_name': dns_name
        })
    }

def delete_rds(db_instance_id):
    print(f"Deleting RDS instance: {db_instance_id}")
    
    rds.delete_db_instance(
        DBInstanceIdentifier=db_instance_id,
        SkipFinalSnapshot=True,
        DeleteAutomatedBackups=True
    )
    
    print("RDS deletion initiated")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'RDS deletion initiated successfully'
        })
    }
```

**Lambda 함수 배포:**

```bash
# Lambda 함수 패키징
zip -r lambda_function.zip lambda_function.py

# Lambda 함수 생성
aws lambda create-function \
  --function-name manage-dev-rds \
  --runtime python3.11 \
  --role arn:aws:iam::123456789012:role/lambda-rds-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 900 \
  --memory-size 256 \
  --environment Variables="{
    DB_INSTANCE_ID=dev-rds,
    HOSTED_ZONE_ID=Z08123456789ABCDEFGH,
    DNS_NAME=dev-rds.internal.mycompany.com,
    DB_PASSWORD=YourSecurePassword123!,
    SECURITY_GROUP_ID=sg-0123456789abcdef,
    DB_SUBNET_GROUP=your-db-subnet-group
  }"
```

**EventBridge 규칙 생성:**

```bash
# 평일 오전 9시 KST (UTC 00:00) - RDS 생성
aws events put-rule \
  --name dev-rds-create \
  --description "Create dev RDS at 9 AM KST on weekdays" \
  --schedule-expression "cron(0 0 ? * MON-FRI *)" \
  --state ENABLED

# Lambda 함수를 타겟으로 추가
aws events put-targets \
  --rule dev-rds-create \
  --targets "Id"="1","Arn"="arn:aws:lambda:ap-northeast-2:123456789012:function:manage-dev-rds","Input"='{"action":"create"}'

# Lambda 실행 권한 부여
aws lambda add-permission \
  --function-name manage-dev-rds \
  --statement-id dev-rds-create-event \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-northeast-2:123456789012:rule/dev-rds-create

# 평일 오후 6시 KST (UTC 09:00) - RDS 삭제
aws events put-rule \
  --name dev-rds-delete \
  --description "Delete dev RDS at 6 PM KST on weekdays" \
  --schedule-expression "cron(0 9 ? * MON-FRI *)" \
  --state ENABLED

aws events put-targets \
  --rule dev-rds-delete \
  --targets "Id"="1","Arn"="arn:aws:lambda:ap-northeast-2:123456789012:function:manage-dev-rds","Input"='{"action":"delete"}'

aws lambda add-permission \
  --function-name manage-dev-rds \
  --statement-id dev-rds-delete-event \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-northeast-2:123456789012:rule/dev-rds-delete
```

**Lambda IAM 역할 정책:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:DescribeDBInstances"
      ],
      "Resource": "arn:aws:rds:ap-northeast-2:123456789012:db:dev-rds"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/Z08123456789ABCDEFGH"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

---

## 전체 워크플로우

```
┌─────────────────────────────────────────────────────┐
│  [09:00 KST] EventBridge/Cron 트리거                │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  스크립트/Lambda: RDS 인스턴스 생성 시작             │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  RDS available 상태 대기 (~5-10분)                   │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  RDS 엔드포인트 주소 가져오기                        │
│  예: dev-rds.c1a2b3.ap-northeast-2.rds.amazonaws.com│
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  Route53 CNAME 레코드 업데이트                       │
│  dev-rds.internal.mycompany.com → RDS 엔드포인트    │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  DNS 전파 (TTL 60초, 거의 즉시 반영)                 │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  Kubernetes Pod가 고정 DNS로 자동 접속               │
│  (애플리케이션 재시작 불필요)                        │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  ... 업무 시간 동안 정상 운영 ...                    │
└───────────────────┬─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│  [18:00 KST] RDS 삭제                                │
│  (DNS 레코드는 유지 - 다음날 재사용)                 │
└─────────────────────────────────────────────────────┘
```

---

## 장점 및 주의사항

### ✅ 장점

1. **애플리케이션 코드 변경 불필요**
   - 고정 DNS 이름만 사용
   - RDS 엔드포인트 변경에 영향받지 않음

2. **Kubernetes 설정 변경 불필요**
   - ConfigMap 한 번 설정으로 끝
   - Pod 재시작 불필요

3. **완전 자동화 가능**
   - 스크립트 또는 Lambda로 관리
   - 스케줄러로 자동 실행

4. **빠른 DNS 전파**
   - TTL 60초로 설정
   - 변경 사항 즉시 반영

5. **보안성**
   - Private Hosted Zone 사용
   - VPC 내부 네트워크만 접근 가능
   - 외부 인터넷에서 접근 불가

6. **비용 효율적**
   - Route53 Private Zone: $0.50/월
   - DNS 쿼리: 100만 건당 $0.40
   - 개발 환경 비용 절감

### ⚠️ 주의사항

1. **VPC 요구사항**
   - EKS 클러스터와 RDS가 **같은 VPC**에 있어야 함
   - Private Hosted Zone은 연결된 VPC 내에서만 해석됨

2. **DNS 전파 시간**
   - 일반적으로 60초 이내 반영
   - Pod의 DNS 캐시 고려 필요

3. **Connection Pool 설정**
   - RDS 삭제 시 기존 연결 끊김
   - 애플리케이션에서 재연결 로직 필요
   
   ```java
   // Spring Boot 예시
   spring.datasource.hikari.connection-test-query=SELECT 1
   spring.datasource.hikari.connection-timeout=30000
   spring.datasource.hikari.validation-timeout=5000
   spring.datasource.hikari.maximum-pool-size=10
   ```

4. **보안 그룹 설정**
   - RDS 보안 그룹에서 EKS 노드 접근 허용
   - 포트: 3306 (MySQL) 또는 5432 (PostgreSQL)

5. **백업 정책**
   - Dev 환경이므로 백업 미설정
   - 필요한 경우 스냅샷 생성 고려

6. **Lambda 타임아웃**
   - RDS 생성 대기 시간 고려
   - 최소 15분(900초) 권장

---

## 문제 해결 (Troubleshooting)

### Pod에서 DNS 해석 안됨

```bash
# CoreDNS 로그 확인
kubectl logs -n kube-system -l k8s-app=kube-dns

# Pod의 DNS 설정 확인
kubectl exec -it <pod-name> -- cat /etc/resolv.conf
```

**해결:**
- Private Hosted Zone이 올바른 VPC에 연결되어 있는지 확인
- VPC DNS resolution과 DNS hostnames 활성화 확인

### RDS 연결 실패

```bash
# 보안 그룹 확인
aws ec2 describe-security-groups --group-ids sg-xxxxx

# RDS 엔드포인트 확인
aws rds describe-db-instances --db-instance-identifier dev-rds
```

**해결:**
- RDS 보안 그룹에서 EKS 노드 보안 그룹 허용
- 서브넷 라우팅 테이블 확인

### DNS 업데이트가 반영 안됨

```bash
# Route53 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id Z08123456789ABCDEFGH \
  --query "ResourceRecordSets[?Name=='dev-rds.internal.mycompany.com.']"
```

**해결:**
- CNAME 레코드가 올바르게 업데이트되었는지 확인
- TTL 대기 후 재시도

---

## 추가 리소스

- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [AWS RDS User Guide](https://docs.aws.amazon.com/rds/)
- [Kubernetes DNS Configuration](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [AWS Lambda with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)

---

## 버전 정보

- 문서 버전: 1.0
- 최종 업데이트: 2025-11-03
- 작성자: Claude (Anthropic)
- 테스트 환경: EKS 1.28, RDS MySQL 8.0, Route53 Private Hosted Zone

---

## 라이선스

이 문서는 자유롭게 사용, 수정, 배포할 수 있습니다.
