# Kind 클러스터에서 MySQL RDS 접근 방법 가이드

## 개요

이 문서는 Kind 기반 Kubernetes 클러스터에서 AWS RDS MySQL 인스턴스에 접근하는 다양한 방법을 설명합니다.

**환경 특성:**
- 로컬 개발환경 (Kind 기반 K8s 클러스터)
- Istio 서비스 메시 설치됨
- RDS는 매일 오전 9시~오후 6시 사이 start/stop
- 필요 시 RDS 삭제 후 재생성

---

## 1. 가장 간단한 방법: ExternalName Service

### 설정

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ExternalName
  externalName: your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

### 사용 방법

애플리케이션에서 접근:
```yaml
# 애플리케이션 설정
DB_HOST: mysql-rds.default.svc.cluster.local
DB_PORT: 3306
```

### 장점
- 설정이 매우 간단
- DNS 기반 라우팅으로 추가 리소스 불필요
- RDS 주소 변경 시 Service만 수정하면 됨
- Istio 유무와 무관하게 동작

### 단점
- Istio의 트래픽 관리 기능 활용 불가
- 연결 풀링이나 로드밸런싱 제어 어려움

---

## 2. Istio에 종속적인 방법: ServiceEntry + VirtualService

### 설정

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: mysql-rds
  namespace: default
spec:
  hosts:
  - mysql-rds.external
  addresses:
  - 240.0.0.1  # 더미 IP (실제로 사용되지 않음)
  ports:
  - number: 3306
    name: mysql
    protocol: TCP
  location: MESH_EXTERNAL
  resolution: DNS
  endpoints:
  - address: your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com
    ports:
      mysql: 3306
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mysql-rds
  namespace: default
spec:
  hosts:
  - mysql-rds.external
  tcp:
  - match:
    - port: 3306
    route:
    - destination:
        host: mysql-rds.external
        port:
          number: 3306
      weight: 100
```

### 고급 설정: Timeout 및 Retry 정책

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mysql-rds
spec:
  hosts:
  - mysql-rds.external
  tcp:
  - match:
    - port: 3306
    route:
    - destination:
        host: mysql-rds.external
      weight: 100
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
```

### 장점
- Istio의 텔레메트리, 모니터링 활용 가능
- 트래픽 정책(retry, timeout) 적용 가능
- Kiali에서 트래픽 흐름 시각화
- Circuit breaker 패턴 적용 가능

### 단점
- Istio 의존성
- 설정 복잡도 증가

---

## 3. Istio에 종속적이지 않은 방법: Endpoints + Service

### 설정

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ClusterIP
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: mysql-rds
  namespace: default
subsets:
- addresses:
  - ip: 10.20.30.40  # RDS 실제 IP 주소
  ports:
  - port: 3306
    protocol: TCP
```

### RDS IP 주소 확인 방법

```bash
# DNS 조회로 RDS IP 확인
nslookup your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com

# 또는 dig 사용
dig +short your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com
```

### 장점
- Kubernetes 네이티브 방식
- Istio 없이도 동작
- 일반적인 Service처럼 사용 가능

### 단점
- RDS IP 변경 시 수동 업데이트 필요
- DNS 대신 IP 사용으로 유연성 감소

---

## 4. 기타 고급 방법들

### A. External Secrets Operator 패턴

RDS 주소를 AWS Systems Manager Parameter Store나 AWS Secrets Manager에 저장하고 동기화합니다.

#### 설치

```bash
# Helm으로 External Secrets Operator 설치
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets-system \
    --create-namespace
```

#### SecretStore 설정

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-parameter-store
  namespace: default
spec:
  provider:
    aws:
      service: ParameterStore
      region: ap-northeast-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

#### ExternalSecret 설정

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rds-connection
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-parameter-store
    kind: SecretStore
  target:
    name: rds-secret
  data:
  - secretKey: DB_HOST
    remoteRef:
      key: /dev/mysql/host
  - secretKey: DB_USER
    remoteRef:
      key: /dev/mysql/username
  - secretKey: DB_PASSWORD
    remoteRef:
      key: /dev/mysql/password
```

#### AWS Parameter Store에 값 저장

```bash
aws ssm put-parameter \
  --name /dev/mysql/host \
  --value "your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com" \
  --type String

aws ssm put-parameter \
  --name /dev/mysql/username \
  --value "admin" \
  --type SecureString

aws ssm put-parameter \
  --name /dev/mysql/password \
  --value "your-password" \
  --type SecureString
```

### B. Headless Service + ExternalName 하이브리드

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  clusterIP: None  # Headless
  type: ExternalName
  externalName: your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com
  ports:
  - port: 3306
```

### C. Envoy Proxy 패턴

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-mysql-config
data:
  envoy.yaml: |
    static_resources:
      listeners:
      - address:
          socket_address:
            address: 0.0.0.0
            port_value: 3306
        filter_chains:
        - filters:
          - name: envoy.filters.network.tcp_proxy
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
              stat_prefix: mysql
              cluster: mysql_cluster
      clusters:
      - name: mysql_cluster
        connect_timeout: 5s
        type: LOGICAL_DNS
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: mysql_cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com
                    port_value: 3306
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-proxy
  template:
    metadata:
      labels:
        app: mysql-proxy
    spec:
      containers:
      - name: envoy
        image: envoyproxy/envoy:v1.28-latest
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: config
          mountPath: /etc/envoy
        command: ["/usr/local/bin/envoy"]
        args: ["-c", "/etc/envoy/envoy.yaml"]
      volumes:
      - name: config
        configMap:
          name: envoy-mysql-config
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
spec:
  selector:
    app: mysql-proxy
  ports:
  - port: 3306
    targetPort: 3306
```

---

## 권장 방식

### 1순위: ExternalName Service (가장 간단한 방법)

**추천 이유:**
- RDS가 자주 재생성되는 환경에 적합
- 설정 변경이 단순 (Service 리소스만 수정)
- Istio 유무와 무관하게 동작
- 개발 환경에서 충분한 기능 제공

**적합한 경우:**
- 빠른 프로토타이핑
- 단순한 개발 환경
- RDS 엔드포인트가 자주 변경됨

### 2순위: ServiceEntry (Istio 사용 시)

**추천 이유:**
- 이미 Istio가 설치되어 있음
- 개발 단계에서 트래픽 모니터링 유용
- 운영으로 전환 시 트래픽 정책 추가 가능

**적합한 경우:**
- Istio 기능 활용 필요
- 트래픽 관찰성 중요
- 향후 운영 환경 전환 계획

### 3순위: External Secrets Operator (보안 중시)

**추천 이유:**
- GitHub에 민감 정보 노출 방지
- 다중 환경(dev/staging/prod) 관리 용이
- 초기 설정 복잡도는 있지만 장기적 이점

**적합한 경우:**
- 보안이 중요한 환경
- 여러 환경 관리 필요
- 자동화된 시크릿 로테이션 필요

---

## 실전 구현 예시

### ExternalName + ConfigMap 조합 (권장)

#### 1. ConfigMap 생성

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: default
data:
  DB_HOST: "mysql-rds.default.svc.cluster.local"
  DB_PORT: "3306"
  DB_NAME: "myapp"
```

#### 2. ExternalName Service 생성

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ExternalName
  externalName: PLACEHOLDER_RDS_ENDPOINT
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

#### 3. Secret 생성 (자격증명)

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: default
type: Opaque
stringData:
  username: admin
  password: your-password
```

#### 4. 애플리케이션 배포

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
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
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

#### 5. 배포 스크립트

```bash
#!/bin/bash
# deploy-rds-connection.sh

# RDS 엔드포인트 가져오기
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Service YAML 생성
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ExternalName
  externalName: ${RDS_ENDPOINT}
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
EOF

# ConfigMap 및 Secret 배포
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# 애플리케이션 배포
kubectl apply -f deployment.yaml

echo "RDS connection configured: ${RDS_ENDPOINT}"
```

---

## GitHub에 RDS 주소 노출 시 보안 우려사항

### 1. 정보 노출 위험

**노출되는 정보:**
- RDS 엔드포인트 URL
- AWS 리전 정보
- 계정 정보 유추 가능
- 데이터베이스 식별자

**실제 위험도:**
- RDS 엔드포인트만으로는 직접 접근 불가
- 그러나 공격 대상 식별 가능
- 다른 취약점과 결합 시 위험 증가

### 2. 구체적 위험 시나리오

```
공개된 정보 예시:
- RDS 엔드포인트: mydb.abc123.ap-northeast-2.rds.amazonaws.com
- 리전: ap-northeast-2 (서울)
- 식별자: mydb

가능한 공격 벡터:
1. 같은 저장소에서 credential 유출 탐색
2. Security Group 설정 오류 탐색
3. 브루트포스 공격 타겟 식별
4. 소셜 엔지니어링 정보로 활용
```

### 3. 완화 방법

#### A. 환경 변수 치환 패턴

**템플릿 파일 (GitHub 저장)**

```yaml
# values-template.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ExternalName
  externalName: ${RDS_ENDPOINT}  # 실제 값은 CI/CD에서 주입
  ports:
  - port: 3306
```

**실제 배포 시 치환**

```bash
# CI/CD 파이프라인에서
envsubst < values-template.yaml | kubectl apply -f -
```

#### B. Sealed Secrets 사용

**설치**

```bash
# Sealed Secrets Controller 설치
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# kubeseal CLI 설치 (macOS)
brew install kubeseal

# 또는 Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-amd64
chmod +x kubeseal-linux-amd64
sudo mv kubeseal-linux-amd64 /usr/local/bin/kubeseal
```

**사용 방법**

```bash
# 일반 Secret 생성
kubectl create secret generic rds-config \
  --from-literal=endpoint=your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com \
  --dry-run=client -o yaml > secret.yaml

# Sealed Secret으로 암호화
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# sealed-secret.yaml은 GitHub에 안전하게 저장 가능
kubectl apply -f sealed-secret.yaml
```

**Sealed Secret YAML 예시**

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: rds-config
  namespace: default
spec:
  encryptedData:
    endpoint: AgBvN8X... # 암호화된 데이터
  template:
    metadata:
      name: rds-config
      namespace: default
```

#### C. Kustomize Overlay 패턴

**디렉토리 구조**

```
k8s/
├── base/
│   ├── service.yaml          # 플레이스홀더 포함
│   ├── deployment.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── rds-patch.yaml    # gitignore에 추가
│   └── prod/
│       ├── kustomization.yaml
│       └── rds-patch.yaml    # gitignore에 추가
└── .gitignore
```

**base/service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
spec:
  type: ExternalName
  externalName: PLACEHOLDER_RDS_ENDPOINT
  ports:
  - port: 3306
```

**base/kustomization.yaml**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - service.yaml
  - deployment.yaml
```

**overlays/dev/rds-patch.yaml (로컬에만 존재)**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
spec:
  externalName: dev-rds.abc123.ap-northeast-2.rds.amazonaws.com
```

**overlays/dev/kustomization.yaml**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - rds-patch.yaml
```

**.gitignore**

```
# 실제 RDS 엔드포인트 정보 제외
overlays/*/rds-patch.yaml
local-config/
*.local.yaml
```

**배포 방법**

```bash
# dev 환경 배포
kubectl apply -k overlays/dev/

# prod 환경 배포
kubectl apply -k overlays/prod/
```

#### D. AWS Systems Manager Parameter Store

**Parameter 저장**

```bash
# RDS 엔드포인트 저장
aws ssm put-parameter \
  --name /dev/mysql/endpoint \
  --value "your-rds-instance.abc123.ap-northeast-2.rds.amazonaws.com" \
  --type SecureString \
  --key-id alias/aws/ssm

# 다른 환경
aws ssm put-parameter \
  --name /prod/mysql/endpoint \
  --value "prod-rds-instance.xyz789.ap-northeast-2.rds.amazonaws.com" \
  --type SecureString
```

**배포 스크립트에서 사용**

```bash
#!/bin/bash
# deploy-with-ssm.sh

ENV=${1:-dev}

# Parameter Store에서 값 가져오기
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "/${ENV}/mysql/endpoint" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

# Service 생성
kubectl create service externalname mysql-rds \
  --external-name=${RDS_ENDPOINT} \
  --tcp=3306:3306 \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Deployed RDS connection for ${ENV}: ${RDS_ENDPOINT}"
```

**ArgoCD/Flux와 통합**

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mysql-connection
spec:
  source:
    repoURL: https://github.com/your-org/your-repo
    path: k8s/overlays/dev
    plugin:
      name: argocd-vault-plugin
      env:
        - name: RDS_ENDPOINT
          value: <path:/dev/mysql/endpoint>
```

---

## 실용적인 워크플로우

### 옵션 1: 로컬 오버라이드 (가장 간단)

#### 설정

```bash
# 프로젝트 루트에서
mkdir -p local-config

# .gitignore에 추가
echo "local-config/" >> .gitignore
```

#### RDS 연결 스크립트

```bash
#!/bin/bash
# scripts/setup-local-rds.sh

# RDS 정보 가져오기
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# 로컬 설정 파일 생성
cat > local-config/rds-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: default
spec:
  type: ExternalName
  externalName: ${RDS_ENDPOINT}
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
EOF

# 배포
kubectl apply -f local-config/rds-service.yaml

echo "✓ RDS connection configured: ${RDS_ENDPOINT}"
```

#### 사용 방법

```bash
# 권한 부여
chmod +x scripts/setup-local-rds.sh

# 실행
./scripts/setup-local-rds.sh
```

### 옵션 2: 환경별 분리 (권장)

#### 디렉토리 구조

```
project/
├── deployments/
│   ├── base/
│   │   ├── mysql-service-template.yaml
│   │   ├── deployment.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       └── prod/
├── scripts/
│   ├── setup-rds-connection.sh
│   └── teardown-rds-connection.sh
├── docs/
│   └── setup-guide.md
└── README.md
```

#### 템플릿 파일

```yaml
# deployments/base/mysql-service-template.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-rds
  namespace: ${NAMESPACE}
spec:
  type: ExternalName
  externalName: ${RDS_ENDPOINT}
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

#### 배포 스크립트

```bash
#!/bin/bash
# scripts/setup-rds-connection.sh

set -e

# 환경 설정
ENV=${1:-dev}
NAMESPACE=${2:-default}

echo "Setting up RDS connection for environment: ${ENV}"

# RDS 엔드포인트 가져오기
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "${ENV}-mydb" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text 2>/dev/null)

if [ -z "$RDS_ENDPOINT" ]; then
  echo "Error: RDS instance not found for environment: ${ENV}"
  exit 1
fi

# 템플릿 치환 및 배포
export NAMESPACE RDS_ENDPOINT
envsubst < deployments/base/mysql-service-template.yaml | kubectl apply -f -

echo "✓ RDS connection configured"
echo "  Environment: ${ENV}"
echo "  Namespace: ${NAMESPACE}"
echo "  Endpoint: ${RDS_ENDPOINT}"
```

#### 정리 스크립트

```bash
#!/bin/bash
# scripts/teardown-rds-connection.sh

NAMESPACE=${1:-default}

kubectl delete service mysql-rds -n ${NAMESPACE} --ignore-not-found

echo "✓ RDS connection removed from namespace: ${NAMESPACE}"
```

#### README.md

```markdown
# RDS Connection Setup

## Quick Start

```bash
# Dev 환경 설정
./scripts/setup-rds-connection.sh dev

# Prod 환경 설정
./scripts/setup-rds-connection.sh prod production
```

## Prerequisites

- kubectl configured
- AWS CLI configured
- RDS instance running

## Cleanup

```bash
./scripts/teardown-rds-connection.sh
```
```

### 옵션 3: CI/CD 통합 (프로덕션 수준)

#### GitHub Actions 예시

```yaml
# .github/workflows/deploy-rds-connection.yaml
name: Deploy RDS Connection

on:
  push:
    branches:
      - main
      - develop
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ secrets.EKS_CLUSTER_NAME }}

      - name: Get RDS Endpoint
        id: rds
        run: |
          RDS_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier ${{ github.event.inputs.environment }}-mydb \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
          echo "endpoint=${RDS_ENDPOINT}" >> $GITHUB_OUTPUT

      - name: Deploy RDS Connection
        run: |
          kubectl create service externalname mysql-rds \
            --external-name=${{ steps.rds.outputs.endpoint }} \
            --tcp=3306:3306 \
            --namespace=${{ github.event.inputs.environment }} \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Verify Deployment
        run: |
          kubectl get service mysql-rds -n ${{ github.event.inputs.environment }}
```

#### GitLab CI 예시

```yaml
# .gitlab-ci.yml
stages:
  - deploy

variables:
  AWS_DEFAULT_REGION: ap-northeast-2

.deploy_template: &deploy_template
  image: amazon/aws-cli:latest
  before_script:
    - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    - chmod +x kubectl
    - mv kubectl /usr/local/bin/
    - aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME}
  script:
    - |
      RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${ENVIRONMENT}-mydb \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
      
      kubectl create service externalname mysql-rds \
        --external-name=${RDS_ENDPOINT} \
        --tcp=3306:3306 \
        --namespace=${ENVIRONMENT} \
        --dry-run=client -o yaml | kubectl apply -f -

deploy_dev:
  <<: *deploy_template
  stage: deploy
  variables:
    ENVIRONMENT: dev
  only:
    - develop

deploy_prod:
  <<: *deploy_template
  stage: deploy
  variables:
    ENVIRONMENT: prod
  only:
    - main
  when: manual
```

#### ArgoCD ApplicationSet

```yaml
# argocd-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: rds-connections
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: default
      - env: staging
        namespace: staging
      - env: prod
        namespace: production
  template:
    metadata:
      name: 'rds-connection-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/your-repo
        targetRevision: HEAD
        path: deployments/overlays/{{env}}
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## 트러블슈팅

### 문제 1: Connection Timeout

**증상:**
```
Error: dial tcp: lookup mysql-rds.default.svc.cluster.local: no such host
```

**해결 방법:**
```bash
# Service 확인
kubectl get service mysql-rds

# DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup mysql-rds.default.svc.cluster.local

# ExternalName 확인
kubectl get service mysql-rds -o jsonpath='{.spec.externalName}'
```

### 문제 2: RDS 접근 거부

**증상:**
```
Error: Access denied for user 'admin'@'ip-address'
```

**해결 방법:**

1. Security Group 확인:
```bash
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].VpcSecurityGroups'
```

2. Kind 클러스터의 외부 IP 확인:
```bash
curl -s https://api.ipify.org
```

3. Security Group에 IP 추가:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 3306 \
  --cidr your-ip/32
```

### 문제 3: Istio에서 연결 실패

**증상:**
```
upstream connect error or disconnect/reset before headers
```

**해결 방법:**

1. ServiceEntry 확인:
```bash
kubectl get serviceentry mysql-rds -o yaml
```

2. 네트워크 정책 확인:
```bash
kubectl get networkpolicy
```

3. Istio 로그 확인:
```bash
kubectl logs -n istio-system deployment/istiod
```

4. 임시로 Istio 우회:
```yaml
# Pod에 annotation 추가
apiVersion: v1
kind: Pod
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

### 문제 4: RDS가 Start/Stop 후 연결 안됨

**증상:**
RDS 재시작 후 애플리케이션에서 연결 실패

**해결 방법:**

1. RDS 상태 확인:
```bash
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].DBInstanceStatus'
```

2. 엔드포인트 재확인:
```bash
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

3. Service 재배포:
```bash
./scripts/setup-rds-connection.sh
```

4. 애플리케이션 Pod 재시작:
```bash
kubectl rollout restart deployment myapp
```

### 문제 5: DNS 캐싱 문제

**증상:**
RDS 엔드포인트는 변경되었지만 이전 IP로 연결 시도

**해결 방법:**

1. CoreDNS 캐시 초기화:
```bash
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

2. 애플리케이션 DNS 캐시 설정:
```yaml
# Pod의 dnsConfig 설정
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "1"
    - name: timeout
      value: "2"
    - name: attempts
      value: "2"
```

---

## 성능 최적화

### 연결 풀링 설정

대부분의 애플리케이션에서 DB 연결 풀링은 필수입니다.

#### Spring Boot 예시

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      connection-test-query: SELECT 1
```

#### Node.js (mysql2) 예시

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});
```

### Istio 연결 풀 설정

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mysql-rds
spec:
  host: mysql-rds.external
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30s
        tcpKeepalive:
          time: 7200s
          interval: 75s
```

---

## 보안 체크리스트

- [ ] RDS Security Group이 필요한 IP만 허용하도록 설정
- [ ] IAM 데이터베이스 인증 사용 고려
- [ ] Secret은 암호화하여 저장 (Sealed Secrets 또는 External Secrets)
- [ ] RDS 엔드포인트는 GitHub에 직접 저장하지 않음
- [ ] 프로덕션 환경에서는 SSL/TLS 연결 강제
- [ ] 최소 권한 원칙에 따라 DB 사용자 권한 설정
- [ ] RDS 감사 로그 활성화
- [ ] 정기적인 비밀번호 로테이션

---

## 모니터링 설정

### Prometheus + Grafana

```yaml
# ServiceMonitor for MySQL metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql-exporter
spec:
  selector:
    matchLabels:
      app: mysql-exporter
  endpoints:
  - port: metrics
    interval: 30s
```

### Istio 메트릭 활용

```bash
# Istio 대시보드 접속
istioctl dashboard kiali

# Grafana에서 Istio 메트릭 확인
# - Connection success rate
# - Request duration
# - Connection pool status
```

---

## 최종 권장사항 요약

| 방법 | 복잡도 | 보안 | 유연성 | 추천 시나리오 |
|------|--------|------|--------|---------------|
| ExternalName | ⭐ | ⭐⭐ | ⭐⭐⭐ | 빠른 프로토타이핑 |
| ServiceEntry | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Istio 환경 |
| External Secrets | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 프로덕션 환경 |
| Kustomize | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 다중 환경 관리 |

**개발 환경 (현재 상황):**
1. **시작**: ExternalName + 로컬 오버라이드
2. **팀 협업**: Kustomize + gitignore
3. **보안 강화**: External Secrets Operator
4. **Istio 활용**: ServiceEntry + DestinationRule

**RDS 주소 관리:**
- GitHub에는 템플릿만 저장
- 실제 값은 로컬 또는 CI/CD 환경변수로 관리
- AWS Parameter Store 통합 시 자동화 가능

---

## 참고 자료

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Istio Service Entry](https://istio.io/latest/docs/reference/config/networking/service-entry/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kustomize](https://kustomize.io/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

---

## 변경 이력

- 2024-11-04: 초기 문서 작성
