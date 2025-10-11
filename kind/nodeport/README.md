# NodePort Services for Kind Cluster

이 디렉토리는 Kind 클러스터 외부에서 인프라 서비스에 접근하기 위한 NodePort 서비스 설정을 포함합니다.

## 개요

Kind 클러스터 내부의 MySQL, Redis 등의 인프라 서비스를 로컬 호스트에서 접근할 수 있도록 NodePort 서비스를 제공합니다.

## 서비스 목록

### MySQL NodePort
- **Service Name**: `mysql-nodeport`
- **Namespace**: `infra`
- **NodePort**: `30306`
- **Target Port**: `3306`
- **Host Access**: `localhost:3306`

### Redis NodePort
- **Service Name**: `redis-nodeport`
- **Namespace**: `infra`
- **NodePort**: `30379`
- **Target Port**: `6379`
- **Host Access**: `localhost:6379`

## 사용 방법

### 1. NodePort 서비스 생성

```bash
kubectl apply -f mysql-nodeport.yaml
kubectl apply -f redis-nodeport.yaml
```

### 2. 서비스 확인

```bash
kubectl get svc -n infra
```

### 3. 클러스터 재생성 (필요한 경우)

**중요**: `cluster.yml`의 `extraPortMappings` 설정이 변경된 경우, 클러스터를 재생성해야 합니다.

```bash
# 기존 클러스터 삭제
./delete-cluster.sh

# 새 클러스터 생성
./create-cluster.sh
```

## 아키텍처

```
┌─────────────────────────────────────────────────┐
│ Host Machine (localhost)                        │
│                                                  │
│  Application connects to:                       │
│  - localhost:3306 (MySQL)                       │
│  - localhost:6379 (Redis)                       │
└────────────┬────────────────────────────────────┘
             │
             │ Kind extraPortMappings
             │
┌────────────▼────────────────────────────────────┐
│ Kind Node (Container)                           │
│                                                  │
│  NodePort Services:                             │
│  - 30306 → MySQL Pod (3306)                     │
│  - 30379 → Redis Pod (6379)                     │
└─────────────────────────────────────────────────┘
```

## 설정 파일

### cluster.yml 설정
```yaml
extraPortMappings:
  - containerPort: 30306  ## MySQL NodePort
    hostPort: 3306
    protocol: TCP
  - containerPort: 30379  ## Redis NodePort
    hostPort: 6379
    protocol: TCP
```

- `containerPort`: Kind 노드 내부의 포트 (NodePort 번호)
- `hostPort`: 호스트 머신에서 접근할 포트

## 테스트 환경 설정

통합 테스트에서 사용하는 설정:

```yaml
# application-local-k8s-test.yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/dailyfeed
  data:
    redis:
      host: localhost
      port: 6379
```

## 문제 해결

### 포트 충돌
호스트 머신에서 이미 3306, 6379 포트를 사용 중인 경우:

1. 기존 서비스 중지 또는
2. `cluster.yml`의 `hostPort` 변경 (예: 13306, 16379)
3. 테스트 설정 파일의 포트도 함께 변경

### 연결 실패
```bash
# NodePort 서비스 상태 확인
kubectl get svc -n infra -o wide

# Pod 상태 확인
kubectl get pods -n infra

# 포트 포워딩 확인 (docker 환경)
docker ps | grep kind
```

## 참고사항

- NodePort는 기본적으로 30000-32767 범위의 포트를 사용합니다
- 클러스터 생성 시에만 `extraPortMappings` 설정이 적용됩니다
- Production 환경에서는 Ingress나 LoadBalancer 사용을 권장합니다