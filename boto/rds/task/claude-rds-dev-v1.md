# Dev 프로필 설치 스크립트 구성 작업 완료 요약

## 작업 개요
- **목적**: dev 프로필에서 MySQL RDS와 MongoDB Atlas를 ExternalName Service로 연결
- **날짜**: 2025-11-04
- **방식**: ExternalName + ConfigMap 조합 (권장 방식)

---

## 1. Secret 자격증명 업데이트

### MySQL Secret (`mysql-secret-dev.yaml`)
- **파일 위치**: `dailyfeed-infrastructure/helm/manifests/dev/mysql-secret-dev.yaml`
- **업데이트 내용**:
  - Username: `dailyfeed`
  - Password: `hitEnter###`
  - Base64 인코딩 적용

### MongoDB Secret (`mongodb-secret-dev.yaml`)
- **파일 위치**: `dailyfeed-infrastructure/helm/manifests/dev/mongodb-secret-dev.yaml`
- **업데이트 내용**:
  - Username: `dailyfeed-search`
  - Password: `hitEnter###`
  - Connection URI: `mongodb+srv://dailyfeed-search:hitEnter###@alpha300.sz30zco.mongodb.net/?appName=alpha300`
  - Base64 인코딩 적용

---

## 2. ExternalName Service 설정

### MySQL RDS Service (`dev-mysql-service.yaml`)
- **파일 위치**: `dailyfeed-infrastructure/helm/kafka_redis_mysql/dev-mysql-service.yaml`
- **설정 내용**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: mysql
    namespace: infra
  spec:
    type: ExternalName
    externalName: dailyfeed-dev.c7muo0wa2dr1.ap-northeast-2.rds.amazonaws.com
    ports:
    - port: 3306
      targetPort: 3306
      protocol: TCP
  ```
- **서비스 이름**: `mysql.infra.svc.cluster.local`
- **특징**: local 프로필과 동일한 서비스 이름 사용 (프로필 격리로 충돌 없음)

### MongoDB Atlas Service (`dev-mongodb-service.yaml`)
- **파일 위치**: `dailyfeed-infrastructure/helm/kafka_redis_mysql/dev-mongodb-service.yaml`
- **설정 내용**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: mongodb
    namespace: infra
  spec:
    type: ExternalName
    externalName: alpha300.sz30zco.mongodb.net
    ports:
    - port: 27017
      targetPort: 27017
      protocol: TCP
  ```
- **서비스 이름**: `mongodb.infra.svc.cluster.local`
- **특징**: 이미 올바르게 설정되어 있었음

---

## 3. 설치 스크립트 구성

### 3.1 `1-install-essential-dev.sh` 업데이트
- **파일 위치**: `dailyfeed-infrastructure/helm/1-install-essential-dev.sh`
- **주요 변경 사항**:
  1. Namespace 생성 (dailyfeed, infra)
  2. ConfigMap, Secret 적용
  3. **Kafka, Redis만 설치** (MySQL, MongoDB는 외부 서비스 사용)
  4. ExternalName Service 적용 (MySQL RDS, MongoDB Atlas, Redis)
  5. CoreDNS 리소스 패치
  6. Istio injection 활성화
  7. Istio 설치
  8. Metrics Server 설치 (HPA용)
  9. 각 단계별 상태 확인

### 3.2 `install-dev.sh` 생성
- **파일 위치**: `dailyfeed-infrastructure/install-dev.sh`
- **주요 내용**:
  1. Kind 클러스터 생성
  2. Essential 인프라 설치 (`1-install-essential-dev.sh` 호출)
  3. 애플리케이션 디버그용 NodePort 생성
     - dailyfeed-member-debug-svc
     - dailyfeed-content-debug-svc
     - dailyfeed-timeline-debug-svc
     - dailyfeed-activity-debug-svc
     - dailyfeed-image-debug-svc
     - dailyfeed-search-debug-svc
  4. **Redis NodePort만 생성** (MySQL, MongoDB는 외부 서비스이므로 불필요)
  5. StorageClass 생성
  6. Istio Ingress Gateway, VirtualService 설치
  7. Istio Addons 설치 (Kiali, Jaeger, Prometheus)
  8. Istio Addons NodePort 설치

### 3.3 `dev-install-infra-and-app.sh` 생성
- **파일 위치**: `dailyfeed-installer/dev-install-infra-and-app.sh`
- **주요 내용**:
  ```bash
  VERSION_ARG="$1"

  # Infrastructure 설치
  cd dailyfeed-infrastructure
  source install-dev.sh
  cd ..

  # Application 설치
  cd dailyfeed-app-helm
  if [ -n "$VERSION_ARG" ]; then
    source install-dev.sh "$VERSION_ARG"
  else
    source install-dev.sh
  fi
  cd ..
  ```
- **특징**:
  - 버전 인자 전달 지원
  - local-install-infra-and-app.sh와 동일한 구조

---

## 4. 주요 특징 및 장점

### 4.1 ExternalName + ConfigMap 조합 방식
- **권장 방식 적용**: 가이드 문서의 권장 사항 준수
- **간단한 설정**: 추가 리소스 없이 DNS 기반 라우팅
- **유연성**: RDS 주소 변경 시 Service만 수정하면 됨
- **Istio 유무와 무관**: Istio가 없어도 동작

### 4.2 동일한 서비스 이름 유지
- **MySQL**: `mysql.infra.svc.cluster.local`
- **MongoDB**: `mongodb.infra.svc.cluster.local`
- **ConfigMap 수정 불필요**: 기존 설정 그대로 사용 가능
- **애플리케이션 코드 변경 없음**: 서비스 이름이 동일하므로 코드 수정 불필요

### 4.3 프로필 격리
- local과 dev가 같은 클러스터에서 실행되지 않음
- 서비스 이름 충돌 없음
- 각 환경에 최적화된 설정

### 4.4 dev 환경 특징
- **로컬 인프라**: Kafka, Redis
- **외부 서비스**: MySQL RDS, MongoDB Atlas
- **디버그 지원**: 각 마이크로서비스별 NodePort 제공
- **모니터링**: Istio Addons (Kiali, Jaeger, Prometheus)

---

## 5. 사용 방법

### 5.1 전체 설치 (버전 없이)
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer
./dev-install-infra-and-app.sh
```

### 5.2 특정 버전으로 설치
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer
./dev-install-infra-and-app.sh v1.0.0
```

### 5.3 인프라만 설치
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer/dailyfeed-infrastructure
./install-dev.sh
```

---

## 6. 보안 및 네트워크 설정

### 6.1 MySQL RDS 보안 그룹 설정
- **필수 작업**: RDS Security Group에서 로컬 IP 허용
- **확인 방법**:
  ```bash
  # 로컬 IP 확인
  curl -s https://api.ipify.org

  # Security Group에 추가
  aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxx \
    --protocol tcp \
    --port 3306 \
    --cidr <your-ip>/32
  ```

### 6.2 MongoDB Atlas Network Access
- **필수 작업**: IP 화이트리스트에 로컬 IP 추가
- **설정 위치**: MongoDB Atlas Console > Network Access > Add IP Address

### 6.3 연결 확인
```bash
# MySQL 연결 테스트
kubectl run -it --rm mysql-test --image=mysql:8.0 --restart=Never -- \
  mysql -h mysql.infra.svc.cluster.local -u dailyfeed -p

# MongoDB 연결 테스트
kubectl run -it --rm mongo-test --image=mongo:7.0 --restart=Never -- \
  mongosh "mongodb+srv://dailyfeed-search:hitEnter###@alpha300.sz30zco.mongodb.net/?appName=alpha300"
```

---

## 7. 설정 파일 요약

### 변경된 파일 목록
1. `dailyfeed-infrastructure/helm/manifests/dev/mysql-secret-dev.yaml` - 자격증명 업데이트
2. `dailyfeed-infrastructure/helm/manifests/dev/mongodb-secret-dev.yaml` - 자격증명 업데이트
3. `dailyfeed-infrastructure/helm/kafka_redis_mysql/dev-mysql-service.yaml` - RDS 엔드포인트 설정
4. `dailyfeed-infrastructure/helm/1-install-essential-dev.sh` - dev 설치 로직 업데이트

### 새로 생성된 파일 목록
1. `dailyfeed-infrastructure/install-dev.sh` - dev 인프라 설치 메인 스크립트
2. `dailyfeed-installer/dev-install-infra-and-app.sh` - dev 전체 설치 스크립트

### 변경되지 않은 파일
- `dailyfeed-infrastructure/helm/manifests/dev/mysql-config-dev.yaml` - 그대로 사용
- `dailyfeed-infrastructure/helm/manifests/dev/mongodb-config-dev.yaml` - 그대로 사용
- `dailyfeed-infrastructure/helm/kafka_redis_mysql/dev-mongodb-service.yaml` - 이미 올바르게 설정됨

---

## 8. 트러블슈팅

### 8.1 Connection Timeout
**증상**: MySQL 또는 MongoDB 연결 시 timeout 발생

**해결 방법**:
```bash
# Service 확인
kubectl get service -n infra mysql mongodb

# DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup mysql.infra.svc.cluster.local

# ExternalName 확인
kubectl get service mysql -n infra -o jsonpath='{.spec.externalName}'
```

### 8.2 Access Denied
**증상**: 자격증명 오류

**해결 방법**:
```bash
# Secret 확인
kubectl get secret mysql-secret -n dailyfeed -o yaml

# Base64 디코딩하여 값 확인
kubectl get secret mysql-secret -n dailyfeed -o jsonpath='{.data.MYSQL_USERNAME}' | base64 -d
kubectl get secret mysql-secret -n dailyfeed -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d
```

### 8.3 RDS 시작/정지 후 연결 안됨
**증상**: RDS가 stop 상태에서 start 후 연결 실패

**해결 방법**:
```bash
# RDS 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier dailyfeed-dev \
  --query 'DBInstances[0].DBInstanceStatus'

# Pod 재시작
kubectl rollout restart deployment -n dailyfeed
```

---

## 9. 다음 단계

### 9.1 애플리케이션 Helm 차트 설정
- `dailyfeed-app-helm/install-dev.sh` 스크립트 생성 필요
- dev 프로필용 values 파일 설정

### 9.2 CI/CD 파이프라인 구성
- GitHub Actions 또는 GitLab CI로 자동 배포
- 환경별 시크릿 관리

### 9.3 모니터링 설정
- Grafana 대시보드 구성
- 알림 설정

---

## 10. 참고 자료

- [Kind MySQL RDS Connection Guide](../../../자료조사/kind-mysql-rds-connection-guide.md)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [MongoDB Atlas Network Security](https://docs.atlas.mongodb.com/security-whitelist/)

---

## 변경 이력

- 2025-11-04: 초기 작업 완료 및 문서 작성
