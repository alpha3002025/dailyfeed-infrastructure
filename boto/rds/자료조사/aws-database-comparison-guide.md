# AWS 데이터베이스 선택 가이드 (RDS, Aurora, PlanetScale)

> 프리티어 종료 후 저렴하게 데이터베이스 구성하기

---

## 목차

1. [AWS 프리티어 종료 후 저렴한 구성](#1-aws-프리티어-종료-후-저렴한-구성)
2. [Savings Plans와 Reserved Instances](#2-savings-plans와-reserved-instances)
3. [개발 단계에서 RI가 필요한가?](#3-개발-단계에서-ri가-필요한가)
4. [Aurora Serverless v2 상세 가이드](#4-aurora-serverless-v2-상세-가이드)
5. [가장 저렴한 옵션: RDS](#5-가장-저렴한-옵션-rds)
6. [PlanetScale MySQL 완벽 가이드](#6-planetscale-mysql-완벽-가이드)
7. [최종 추천 및 비교](#7-최종-추천-및-비교)

---

## 1. AWS 프리티어 종료 후 저렴한 구성

### 💰 저렴한 구성 옵션

#### 1-1. RDS (MySQL/PostgreSQL) - 가장 경제적

```yaml
인스턴스: db.t4g.micro (ARM 기반)
- vCPU: 2개
- 메모리: 1GB
- 스토리지: 20GB gp3
- Single-AZ
- 자동 백업: 7일
```

**예상 월 비용: 약 $15-20**
- 인스턴스: ~$12.41 (서울 리전 기준)
- 스토리지 (20GB gp3): ~$2.76
- 백업 스토리지: 처음 20GB 무료

#### 1-2. Aurora Serverless v2 - 트래픽 변동이 큰 경우

```yaml
최소 용량: 0.5 ACU
최대 용량: 1 ACU
- 사용하지 않을 때 자동 스케일 다운
```

**예상 월 비용: 약 $30-50** (사용 패턴에 따라 변동)

#### 1-3. Aurora (일반) - 안정적 운영 필요시

```yaml
인스턴스: db.t4g.medium
- 최소 권장 사양
```

**예상 월 비용: 약 $50-60**

### 🎯 추천 구성 (개발/테스트 환경)

```yaml
서비스: RDS MySQL 8.0 또는 PostgreSQL
인스턴스: db.t4g.micro
리전: ap-northeast-2 (서울)
배포: Single-AZ
스토리지: 
  - 타입: gp3
  - 크기: 20GB
  - IOPS: 3000 (기본)
백업:
  - 보관 기간: 7일
  - 백업 윈도우: 새벽 시간대
모니터링: 기본 모니터링
```

### 💡 비용 절감 팁

1. **Savings Plans 구매** (EC2/Lambda용)
   - 1년 약정: ~20% 할인
   - 3년 약정: ~40% 할인

2. **Reserved Instances** (RDS용)
   - db.t4g.micro 1년 선결제: 약 $95 (월 $8 수준)

3. **스토리지 최적화**
   - gp2 대신 gp3 사용 (20% 저렴)
   - 불필요한 백업 스냅샷 삭제

4. **리전 선택**
   - 서울 리전이 버지니아보다 약간 비쌈
   - 레이턴시가 중요하지 않다면 미국 리전 고려

5. **개발/테스트 환경**
   - 업무 시간에만 운영 (Lambda로 자동 시작/중지)
   - 월 ~60% 비용 절감 가능

### 📊 실제 월 예상 비용 비교

| 구성 | 온디맨드 | 1년 RI | 3년 RI |
|------|---------|--------|--------|
| db.t4g.micro | $15-20 | $10-12 | $8-10 |
| db.t3.small | $30-35 | $20-22 | $15-18 |
| Aurora Serverless v2 (0.5 ACU) | $30-50 | - | - |

### 🚀 시작 가이드

```bash
# AWS CLI로 RDS 생성 예시
aws rds create-db-instance \
    --db-instance-identifier my-db-instance \
    --db-instance-class db.t4g.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password yourpassword \
    --allocated-storage 20 \
    --storage-type gp3 \
    --backup-retention-period 7 \
    --no-multi-az \
    --region ap-northeast-2
```

---

## 2. Savings Plans와 Reserved Instances

### 📋 Savings Plans 종류

#### 2-1. Compute Savings Plans (가장 유연)
- **적용 대상**: EC2, Lambda, Fargate
- **할인율**: 최대 66%
- **유연성**: 인스턴스 패밀리, 크기, OS, 리전 변경 가능

#### 2-2. EC2 Instance Savings Plans
- **적용 대상**: EC2만
- **할인율**: 최대 72%
- **유연성**: 같은 인스턴스 패밀리 내에서만

#### 2-3. SageMaker Savings Plans
- ML 워크로드 전용

### 💰 작동 방식

```
시간당 $10 사용을 약정했다면:

실제 사용량          Savings Plans 적용       추가 온디맨드 요금
─────────────────────────────────────────────────────────────
시간당 $8 사용   →   $8 (할인가)        →   $0
시간당 $10 사용  →   $10 (할인가)       →   $0
시간당 $15 사용  →   $10 (할인가)       →   $5 (정상가)
```

### 🆚 Reserved Instances vs Savings Plans

| 구분 | Reserved Instances | Savings Plans |
|------|-------------------|---------------|
| **할인율** | 최대 75% | 최대 72% |
| **유연성** | 낮음 (고정된 인스턴스) | 높음 (자유롭게 변경) |
| **적용 범위** | RDS, EC2, ElastiCache 등 | EC2, Lambda, Fargate |
| **추천** | 변경 없는 안정적 워크로드 | 변화가 많은 환경 |

### ⚠️ 중요: RDS는 Savings Plans 적용 안 됨!

**RDS는 Reserved Instances만 지원합니다.**

#### RDS Reserved Instances 옵션

```yaml
결제 옵션:
  1. 전액 선결제 (All Upfront): 최대 할인
  2. 부분 선결제 (Partial Upfront): 중간 할인
  3. 선결제 없음 (No Upfront): 최소 할인

기간:
  - 1년 약정: ~35-40% 할인
  - 3년 약정: ~60-65% 할인
```

### 💡 실제 비용 예시 (RDS db.t4g.micro, 서울 리전)

```
온디맨드:
- 시간당: $0.017
- 월 예상: $12.41

1년 Reserved Instance (전액 선결제):
- 총 비용: ~$95
- 월 환산: ~$7.92 (36% 할인)

3년 Reserved Instance (전액 선결제):
- 총 비용: ~$175
- 월 환산: ~$4.86 (61% 할인)
```

### 🎯 언제 사용하면 좋을까?

**Reserved Instances 구매 추천:**
- ✅ 최소 1년 이상 계속 사용할 확실한 워크로드
- ✅ 인스턴스 타입/크기가 고정적
- ✅ 예산이 확정된 프로젝트

**온디맨드 유지 추천:**
- ❌ 단기 프로젝트 (6개월 미만)
- ❌ 개발/테스트 환경 (자주 삭제)
- ❌ 요구사항이 자주 변경되는 경우

---

## 3. 개발 단계에서 RI가 필요한가?

### 🚫 Reserved Instance를 피해야 하는 이유

#### 3-1. 유연성 부족

```
개발 중 흔한 상황:
- "MySQL에서 PostgreSQL로 바꿔볼까?"
- "스펙이 부족한데 인스턴스 업그레이드 필요"
- "프로젝트 방향이 바뀌어서 DB가 필요 없어짐"

→ RI 구매 시: 환불 불가, 1년 동안 묶여있음
```

#### 3-2. 비용 효율성 낮음

```
개발 단계 실제 사용 패턴:
- 평일 저녁 2-3시간만 개발
- 주말에는 사용 안 함
- 테스트 후 자주 삭제/재생성

→ 실제 가동률: 20-30%
→ RI 구매하면 오히려 손해
```

#### 3-3. 개발 단계의 변동성
- 기능 추가/삭제로 DB 스키마 자주 변경
- 성능 테스트 위해 인스턴스 크기 실험
- 서비스 아키텍처 변경 가능성

### ✅ 개발 단계 추천 구성

#### 온디맨드 + 자동 시작/중지

```python
# Lambda 함수로 개발 시간에만 RDS 실행
import boto3

rds = boto3.client('rds')

def lambda_handler(event, context):
    db_instance = 'my-dev-db'
    action = event['action']  # 'start' or 'stop'
    
    if action == 'start':
        rds.start_db_instance(DBInstanceIdentifier=db_instance)
    else:
        rds.stop_db_instance(DBInstanceIdentifier=db_instance)
```

**비용 절감 효과:**
- 하루 6시간만 실행 (75% 절감)
- 주말 중지 (추가 28% 절감)
- **최종: 월 $15 → $4-5 수준**

### 🎯 단계별 전략

```
개발 단계 (지금):
└─> 온디맨드 db.t4g.micro + 자동 중지
    ($4-5/월)

베타/알파 테스트:
└─> 온디맨드 db.t4g.small
    (24시간 운영, $30/월)

프로덕션 런칭 후 3-6개월:
└─> 사용 패턴 분석
    └─> 안정적이면 RI 구매 고려
        (1년 약정, 40% 할인)
```

### 💡 개발 단계 추가 절감 팁

1. **로컬 개발 최대 활용**
   ```bash
   docker run -d \
     -p 3306:3306 \
     -e MYSQL_ROOT_PASSWORD=password \
     mysql:8.0
   ```

2. **Free Tier 다른 서비스 활용**
   - DynamoDB: 25GB 무료 (영구)
   - MongoDB Atlas: 512MB 무료

3. **주말 장기 미사용 시 스냅샷 활용**
   ```
   1. 금요일 밤: 스냅샷 생성
   2. 인스턴스 삭제
   3. 월요일: 스냅샷에서 복원
   ```

### ⏰ Reserved Instance 고려 시점

다음 조건을 **모두** 만족할 때:

✅ 서비스가 실제 사용자에게 오픈됨  
✅ 최소 6개월간 안정적으로 운영됨  
✅ 향후 1년 이상 운영 확실함  
✅ 인스턴스 타입/크기 변경 계획 없음  
✅ 비용 절감이 유연성보다 중요함  

---

## 4. Aurora Serverless v2 상세 가이드

### 🚀 Aurora Serverless v2란?

**사용량에 따라 자동으로 용량을 조절하는 Aurora 데이터베이스**입니다.

### 📊 핵심 개념: ACU (Aurora Capacity Unit)

```
1 ACU = 약 2GB 메모리 + 해당하는 CPU/네트워킹

용량 범위 설정:
- 최소: 0.5 ACU (1GB 메모리)
- 최대: 128 ACU (256GB 메모리)

스케일링:
- 0.5 ACU 단위로 조정
- 초 단위로 자동 확장/축소
```

### 💰 비용 구조 (서울 리전)

```yaml
컴퓨팅 비용:
  ACU당 시간당: $0.16
  
스토리지 비용:
  GB당 월: $0.11
  
I/O 비용:
  백만 요청당: $0.22

백업 스토리지:
  DB 크기만큼 무료
  초과분 GB당: $0.023/월
```

### 💵 실제 비용 계산 예시

**시나리오 1: 최소 사용 (개발 초기)**
```
설정: 최소 0.5 ACU, 최대 2 ACU
실제 사용: 평균 0.5 ACU
스토리지: 10GB

월 비용:
- 컴퓨팅: 0.5 ACU × $0.16 × 730시간 = $58.40
- 스토리지: 10GB × $0.11 = $1.10
- I/O: $2-5
───────────────────────────────────────
총합: 약 $62-65/월
```

**시나리오 2: 변동이 큰 경우**
```
평일 오전 9시-6시: 2 ACU
나머지 시간: 0.5 ACU

월 비용: 약 $110-120/월
```

### 🆚 RDS vs Aurora Serverless v2

| 항목 | RDS db.t4g.micro | Aurora Serverless v2 |
|------|------------------|----------------------|
| **최소 월 비용** | $15-20 | $60-65 |
| **스케일링** | 수동 (다운타임) | 자동 (무중단) |
| **최소 스펙** | 1GB RAM | 1GB RAM (0.5 ACU) |
| **고가용성** | Single-AZ | Multi-AZ (기본) |
| **성능** | 제한적 | 더 우수 |

### ⚙️ Aurora Serverless v2 구성

#### AWS CLI로 생성

```bash
# 클러스터 생성
aws rds create-db-cluster \
    --db-cluster-identifier my-aurora-cluster \
    --engine aurora-mysql \
    --engine-version 8.0.mysql_aurora.3.05.2 \
    --master-username admin \
    --master-user-password YourPassword123! \
    --database-name mydb \
    --serverlessv2-scaling-configuration MinCapacity=0.5,MaxCapacity=2 \
    --region ap-northeast-2

# DB 인스턴스 추가
aws rds create-db-instance \
    --db-instance-identifier my-aurora-instance-1 \
    --db-cluster-identifier my-aurora-cluster \
    --db-instance-class db.serverless \
    --engine aurora-mysql \
    --region ap-northeast-2
```

#### Terraform으로 구성

```hcl
resource "aws_rds_cluster" "aurora_serverless_v2" {
  cluster_identifier      = "my-aurora-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.05.2"
  database_name           = "mydb"
  master_username         = "admin"
  master_password         = var.db_password
  
  backup_retention_period = 7
  
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2.0
  }
  
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "my-aurora-instance-1"
  cluster_identifier = aws_rds_cluster.aurora_serverless_v2.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_serverless_v2.engine
}
```

### 🔗 애플리케이션 연결

#### Spring Boot

```yaml
spring:
  datasource:
    url: jdbc:mysql://my-aurora-cluster.cluster-xxxxx.ap-northeast-2.rds.amazonaws.com:3306/mydb
    username: admin
    password: ${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
    
  hikari:
    minimum-idle: 2
    maximum-pool-size: 10
```

#### Node.js

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: 'my-aurora-cluster.cluster-xxxxx.ap-northeast-2.rds.amazonaws.com',
  user: 'admin',
  password: process.env.DB_PASSWORD,
  database: 'mydb',
  connectionLimit: 10
});
```

### ✅ Aurora Serverless v2 장점

1. **자동 스케일링**: 수동 개입 없이 트래픽 대응
2. **무중단 확장**: 스케일링 중에도 연결 유지
3. **고가용성**: 기본 Multi-AZ 구성
4. **빠른 장애 복구**: 1-2분 내 복구

### ❌ 단점 및 주의사항

1. **최소 비용 높음**: 월 $58+
2. **예측 어려운 비용**: 트래픽에 따라 변동
3. **학습 곡선**: RDS보다 복잡

### 🎯 추천 시나리오

**✅ 적합:**
- 트래픽 변동이 큰 애플리케이션
- 스타트업 초기 단계 (성장 예상)
- 고가용성이 중요한 프로덕션

**❌ 부적합:**
- 최소 비용을 원하는 개인 프로젝트
- 안정적으로 낮은 트래픽
- 비용 예측이 중요한 경우

---

## 5. 가장 저렴한 옵션: RDS

### 💰 실제 비용 비교 (서울 리전)

```
RDS db.t4g.micro:
├─ 온디맨드 24시간: $15-20/월
├─ 자동 중지 (8시간/일): $5-7/월
└─ 1년 RI 선결제: $8/월

Aurora Serverless v2:
└─ 24시간 최소 용량: $60-65/월

차이: 약 3-12배
```

### 🎯 각 서비스 선택 가이드

#### RDS 추천 상황 ✅

```yaml
개인 프로젝트 개발:
  - 예산 최소화 필요
  - 본인만 사용
  → db.t4g.micro + 자동 중지 ($5/월)

소규모 프로덕션:
  - 일 방문자 ~1,000명
  - 안정적 트래픽
  → db.t4g.small ($30/월)

비용 민감형:
  - 스타트업 초기
  - 수익 모델 검증 전
```

#### Aurora Serverless v2 추천 상황 ✅

```yaml
트래픽 변동:
  - 출퇴근 시간 몰림
  - 주말/평일 차이
  - 이벤트성 스파이크

프로덕션 고가용성:
  - 다운타임 불가
  - 자동 장애 복구
  - Multi-AZ 필수

빠른 성장:
  - 사용자 급증 예상
  - 수동 관리 부담
```

### 📊 단계별 추천 전략

```
Phase 1: 개발 (혼자)
→ RDS db.t4g.micro + 자동 중지 = $5-7/월

Phase 2: 베타 테스트
→ RDS db.t4g.micro 24시간 = $15-20/월

Phase 3: 소프트 런칭
→ RDS db.t4g.small = $30-60/월

Phase 4: 성장기
→ Aurora Serverless v2 = $100-200/월

Phase 5: 안정기
→ RDS Reserved Instance (1-3년 약정)
```

### 💡 극한의 비용 절감

#### Lambda 자동 시작/중지

```python
import boto3
import os

rds = boto3.client('rds', region_name='ap-northeast-2')
DB_INSTANCE = os.environ['DB_INSTANCE_ID']

def lambda_handler(event, context):
    action = event.get('action', 'status')
    
    if action == 'start':
        rds.start_db_instance(DBInstanceIdentifier=DB_INSTANCE)
    elif action == 'stop':
        rds.stop_db_instance(DBInstanceIdentifier=DB_INSTANCE)
```

**CloudWatch Events 규칙:**
```yaml
평일 오후 6시 시작: Cron: 0 9 * * MON-FRI (UTC)
자정 중지: Cron: 0 15 * * *

비용 효과: $15 → $4-5/월
```

#### 로컬 개발 + 클라우드 최소화

```bash
# Docker Compose
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: mydb
    ports:
      - "3306:3306"
```

AWS RDS는 통합 테스트/데모용으로만 사용 → 월 $2-3

#### 무료 대안

```yaml
Supabase (PostgreSQL):
  - 500MB 무료
  - GUI + Auth 포함

PlanetScale (MySQL):
  - 5GB 무료
  - 자동 백업

MongoDB Atlas:
  - 512MB 무료

Neon (PostgreSQL):
  - 3GB 무료
  - Serverless
```

---

## 6. PlanetScale MySQL 완벽 가이드

### 🌍 PlanetScale이란?

**MySQL 호환 Serverless 데이터베이스**로, Vitess 기술 기반의 관리형 서비스입니다.

### 핵심 특징

```yaml
기반 기술:
  - Vitess: YouTube 개발
  - MySQL 8.0 호환
  - 수평 확장 자동화

특별한 기능:
  - Git 같은 브랜칭
  - 무중단 스키마 변경
  - 자동 백업
  - 글로벌 배포
```

### 💰 요금제

#### Free (Hobby) 플랜 ⭐

```yaml
스토리지: 5GB
브랜치:
  - 1개 프로덕션
  - 2개 개발

읽기/쓰기:
  - 월 10억 row reads
  - 월 1천만 row writes
  
커넥션: 1,000 동시 연결
백업: 1일 보관

비용: $0/월 (완전 무료)
```

#### Scaler 플랜

```yaml
스토리지: 10GB (추가 $1.50/GB)
읽기: 월 100억 rows
백업: 7일 보관
Insights 포함

비용: $39/월~
```

### 🚀 PlanetScale 장점

#### 1. Git 같은 브랜치 워크플로우

```bash
# 개발 브랜치 생성
planetscale branch create mydb feature-branch

# 스키마 변경
ALTER TABLE users ADD COLUMN email_verified BOOLEAN;

# Deploy Request 생성
planetscale deploy-request create mydb feature-branch

# 프로덕션 병합 (무중단)
planetscale deploy-request deploy mydb [number]
```

**장점:**
- 프로덕션 직접 수정 안 함
- 코드 리뷰처럼 스키마 검토
- 간편한 롤백

#### 2. 무중단 스키마 변경

```sql
-- 일반 MySQL: 테이블 락
ALTER TABLE orders ADD INDEX idx_user_id (user_id);
-- 큰 테이블이면 수 분~수 시간 다운타임

-- PlanetScale: 무중단
-- Ghost 알고리즘으로 백그라운드 처리
```

#### 3. 자동 백업 및 복구

```yaml
자동 백업:
  - 매일 자동 (Free: 1일, Scaler: 7일)
  - 특정 시점 복구

수동 백업:
  - 언제든지 스냅샷
  - 새 브랜치로 복원
```

#### 4. 수평 확장 준비

```yaml
Vitess 기반:
  - 초기: 단일 노드
  - 나중: 샤딩 확장
  - 코드 변경 최소

YouTube, Slack이 사용하는 기술
```

### 📋 시작하기

#### CLI 설치 및 설정

```bash
# CLI 설치
brew install planetscale/tap/pscale

# 로그인
pscale auth login

# 데이터베이스 생성
pscale database create mydb --region ap-northeast

# 브랜치 확인
pscale branch list mydb
```

#### 연결 설정

**Spring Boot:**

```yaml
spring:
  datasource:
    url: jdbc:mysql://aws.connect.psdb.cloud/mydb?sslMode=VERIFY_IDENTITY
    username: ${PLANETSCALE_USERNAME}
    password: ${PLANETSCALE_PASSWORD}
    
  jpa:
    hibernate:
      ddl-auto: none  # 브랜치로 스키마 관리
```

**Node.js:**

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: 'aws.connect.psdb.cloud',
  username: process.env.PLANETSCALE_USERNAME,
  password: process.env.PLANETSCALE_PASSWORD,
  database: 'mydb',
  ssl: { rejectUnauthorized: true }
});
```

#### 스키마 마이그레이션

```bash
# 1. 개발 브랜치 생성
pscale branch create mydb dev-add-users

# 2. 연결
pscale connect mydb dev-add-users --port 3306

# 3. 스키마 변경
CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# 4. Deploy Request (Web UI)
# 5. 검토 후 프로덕션 배포
```

### 🆚 AWS RDS vs PlanetScale

| 항목 | AWS RDS | PlanetScale Free |
|------|---------|------------------|
| **비용** | $15-20/월 | $0/월 |
| **스토리지** | 20GB | 5GB |
| **관리** | 직접 필요 | 완전 관리형 |
| **스키마 변경** | 다운타임 가능 | 무중단 |
| **백업** | 수동 설정 | 자동 |
| **브랜치** | 없음 | Git 워크플로우 |
| **커스터마이징** | 높음 | 제한적 |

### ⚠️ PlanetScale 제약사항

#### 1. Foreign Key 미지원

```sql
-- ❌ 작동 안 함
CREATE TABLE orders (
  id BIGINT PRIMARY KEY,
  user_id BIGINT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ✅ 애플리케이션 레벨 관리
CREATE TABLE orders (
  id BIGINT PRIMARY KEY,
  user_id BIGINT,
  INDEX idx_user_id (user_id)
);
```

**이유**: Vitess의 수평 확장 설계

#### 2. DDL 제한

```sql
-- ❌ 직접 production 실행 불가
ALTER TABLE users ADD COLUMN ...;

-- ✅ 브랜치 워크플로우 필수
```

#### 3. 일부 MySQL 기능 제한

```yaml
미지원:
  - FULLTEXT 인덱스
  - Spatial 데이터
  - Triggers (제한)
  - Stored Procedures (제한)
  - Views (읽기만)
```

### 🎯 PlanetScale 추천 시나리오

#### ✅ 적합한 경우

```yaml
개인 프로젝트:
  - 무료로 시작
  - 5GB 이하
  - DevOps 부담 감소

팀 프로젝트:
  - Git 스키마 관리
  - 무중단 배포
  - 스키마 리뷰

성장 서비스:
  - 글로벌 확장
  - 샤딩 필요
  - 수평 확장
```

#### ❌ 부적합한 경우

```yaml
Foreign Key 필수:
  - 복잡한 관계형
  - DB 무결성 제약

특수 MySQL 기능:
  - Stored Procedures
  - Triggers
  - FULLTEXT 검색

완전한 제어:
  - 서버 커스터마이징
  - 특정 버전 고정
  - 벤더 락인 우려
```

### 💡 실전 팁

#### 로컬 개발

```yaml
로컬: Docker MySQL
├─ 빠른 개발
├─ Foreign Key 사용
└─ 무제한 실험

PlanetScale: 스테이징/프로덕션
├─ 실제 데이터 테스트
├─ 팀원 공유
└─ CI/CD 통합
```

#### Prisma와 함께

```bash
# Prisma 설치
npm install prisma @prisma/client

# schema.prisma
datasource db {
  provider     = "mysql"
  url          = env("DATABASE_URL")
  relationMode = "prisma"  # PlanetScale용
}

# 마이그레이션
npx prisma db push
```

#### 모니터링

```yaml
Dashboard 제공:
  - Query Insights
  - 느린 쿼리 분석
  - 연결 수 모니터링
  - 스토리지 사용량

무료 플랜도 기본 메트릭 포함
```

---

## 7. 최종 추천 및 비교

### 📊 개인 프로젝트 개발 단계 추천 순위

```
1위: PlanetScale Free
     ✅ $0/월
     ✅ 5GB 스토리지
     ✅ 완전 관리형
     ✅ Git 워크플로우
     ✅ 무중단 배포
     ⚠️ Foreign Key 미지원
    
2위: RDS db.t4g.micro + 자동 중지
     ✅ $5/월
     ✅ 20GB 스토리지
     ✅ 완전한 MySQL
     ✅ 커스터마이징 가능
     ⚠️ 수동 관리 필요
    
3위: Supabase
     ✅ $0/월
     ✅ 500MB
     ✅ PostgreSQL
     ✅ GUI + Auth 포함
     ⚠️ 스토리지 적음
    
4위: RDS db.t4g.micro 24시간
     ✅ $15/월
     ✅ 안정적
     ✅ AWS 생태계
     ⚠️ 비용 높음

꼴찌: Aurora Serverless v2
      ❌ $60/월
      ❌ 개발 단계 과함
```

### 💰 상황별 최적 선택

#### 개발 초기 (혼자 개발)

```
추천: PlanetScale Free 또는 로컬 Docker
이유: 
  - 비용 $0
  - 관리 부담 없음
  - 충분한 성능
```

#### 베타 테스트 (소수 테스터)

```
추천: RDS db.t4g.micro
이유:
  - 안정적
  - 예측 가능한 비용 ($15/월)
  - AWS 생태계 활용
```

#### 소프트 런칭 (실사용자 유입)

```
추천: RDS db.t4g.small 또는 PlanetScale Scaler
이유:
  - 충분한 성능
  - 모니터링 중요
  - 비용 최적화 ($30-40/월)
```

#### 빠른 성장기

```
추천: Aurora Serverless v2
이유:
  - 자동 스케일링
  - 고가용성
  - 관리 부담 감소
비용: $100-200/월
```

#### 안정기 (예측 가능)

```
추천: RDS Reserved Instance
이유:
  - 최대 60% 할인
  - 안정적 워크로드
  - 예산 확정
비용: $30-50/월 (3년 약정)
```

### 🎯 의사결정 플로우차트

```
시작
 │
 ├─ 비용이 최우선? ────────────────┐
 │   예                           │
 │   ↓                            │
 │  PlanetScale Free 또는         │
 │  RDS + 자동 중지               │
 │                                │
 ├─ 트래픽 변동 큼? ──────────────┤
 │   예                           │
 │   ↓                            │
 │  Aurora Serverless v2          │
 │                                │
 ├─ Foreign Key 필수? ────────────┤
 │   예                           │
 │   ↓                            │
 │  RDS                           │
 │                                │
 ├─ Git 워크플로우 원함? ─────────┤
 │   예                           │
 │   ↓                            │
 │  PlanetScale                   │
 │                                │
 └─ 고가용성 필수? ───────────────┘
     예
     ↓
    Aurora 또는 RDS Multi-AZ
```

### 📈 비용 총정리

| 서비스 | 최소 비용 | 적정 비용 | 특징 |
|--------|----------|----------|------|
| PlanetScale Free | $0 | $0 | 5GB, Git 워크플로우 |
| RDS + 자동중지 | $4-5 | $5-7 | 20GB, 부분 운영 |
| RDS 온디맨드 | $15 | $20 | 24시간, 안정적 |
| RDS RI (1년) | $8 | $12 | 약정 필요 |
| Aurora Serverless v2 | $60 | $100-150 | 자동 스케일링 |

### ✅ 최종 결론

**개인 프로젝트 개발 단계에서는:**

1. **무료로 시작**: PlanetScale Free
2. **조금 투자 가능**: RDS db.t4g.micro + 자동 중지 ($5/월)
3. **안정적 운영**: RDS db.t4g.micro 24시간 ($15/월)

**Aurora Serverless v2는 프로덕션에서 실제 트래픽이 발생하고, 변동이 큰 경우에만 고려하세요!**

---

## 부록: 유용한 명령어 모음

### RDS 관리

```bash
# 인스턴스 시작
aws rds start-db-instance --db-instance-identifier my-db

# 인스턴스 중지
aws rds stop-db-instance --db-instance-identifier my-db

# 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier my-db \
  --query 'DBInstances[0].DBInstanceStatus'

# 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier my-db \
  --db-snapshot-identifier my-snapshot-$(date +%Y%m%d)
```

### PlanetScale CLI

```bash
# 데이터베이스 목록
pscale database list

# 브랜치 목록
pscale branch list mydb

# 연결
pscale connect mydb main --port 3306

# Deploy Request 목록
pscale deploy-request list mydb

# 스키마 비교
pscale branch diff mydb main dev-branch
```

### Aurora 관리

```bash
# 클러스터 상태
aws rds describe-db-clusters \
  --db-cluster-identifier my-aurora-cluster

# ACU 사용량 확인 (CloudWatch)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=my-aurora-cluster \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

---

**문서 작성일**: 2025년 11월  
**버전**: 1.0  
**작성자**: Claude (Anthropic)
