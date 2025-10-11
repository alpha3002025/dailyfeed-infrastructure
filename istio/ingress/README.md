# Istio Ingress Gateway 구성 가이드

## 개요

Kubernetes 표준 Ingress를 Istio Ingress Gateway로 마이그레이션하는 설정입니다.

## 현재 구성 (Kubernetes Ingress)

기존 설정 (`kind/ingress.yaml`):
- **서비스**: `dailyfeed-frontend`
- **포트**: 3000 (서비스 포트)
- **호스트**: `dailyfeed.local`
- **경로**: `/` (Prefix 매칭)
- **Ingress Controller**: nginx

## Istio 기반 구성

Istio Ingress Gateway는 두 가지 주요 리소스로 구성됩니다:

### 1. Gateway (`gateway.yaml`)

Gateway는 외부 트래픽이 메시로 진입하는 진입점을 정의합니다.

**주요 특징**:
- Istio의 기본 ingress gateway 사용 (`istio: ingressgateway` selector)
- HTTP 포트 80으로 트래픽 수신
- `dailyfeed.local` 및 모든 호스트(`*`) 허용 (개발 환경용)
- HTTPS(443) 설정은 주석 처리됨 (인증서 필요 시 활성화)

### 2. VirtualService (`virtualservice.yaml`)

VirtualService는 Gateway를 통해 들어온 트래픽을 실제 서비스로 라우팅하는 규칙을 정의합니다.

**주요 특징**:
- `/` 경로의 모든 요청을 `dailyfeed-frontend:3000` 서비스로 라우팅
- 타임아웃: 30초
- 재시도 정책: 최대 3회, 시도당 10초 타임아웃
- CORS 정책은 주석 처리됨 (필요 시 활성화)

## Kubernetes Ingress vs Istio Gateway 비교

| 항목 | Kubernetes Ingress | Istio Gateway + VirtualService |
|------|-------------------|--------------------------------|
| **라우팅 기능** | 기본적인 HTTP/HTTPS 라우팅 | 고급 트래픽 관리 (가중치, 헤더, 재시도 등) |
| **프로토콜 지원** | HTTP/HTTPS | HTTP/HTTPS/TCP/gRPC |
| **트래픽 제어** | 제한적 | 세밀한 제어 (카나리, A/B 테스트 등) |
| **서비스 메시 통합** | 없음 | 완전 통합 |
| **관찰성** | 제한적 | Istio 텔레메트리 완전 지원 |
| **보안** | TLS 종료 | mTLS, JWT, 인증/인가 정책 |

## 배포 방법

### 1. Istio가 설치되어 있는지 확인

```bash
kubectl get pods -n istio-system
```

Istio ingress gateway pod가 실행 중이어야 합니다.

### 2. dailyfeed namespace에 Istio sidecar injection 활성화

```bash
kubectl label namespace dailyfeed istio-injection=enabled
```

### 3. Istio Ingress 리소스 배포

```bash
# Gateway 배포
kubectl apply -f istio/ingress/gateway.yaml

# VirtualService 배포
kubectl apply -f istio/ingress/virtualservice.yaml
```

### 4. 배포 확인

```bash
# Gateway 확인
kubectl get gateway -n dailyfeed

# VirtualService 확인
kubectl get virtualservice -n dailyfeed

# Istio ingress gateway 서비스 확인
kubectl get svc -n istio-system istio-ingressgateway
```

### 5. 기존 Kubernetes Ingress 삭제 (선택)

Istio Gateway가 정상 작동하는 것을 확인한 후:

```bash
kubectl delete -f kind/ingress.yaml
```

## 포트 매핑

### Kind 클러스터 구성

Kind 클러스터 생성 시 다음 포트 매핑이 필요합니다:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080  # Istio ingress gateway NodePort (HTTP)
    hostPort: 80
    protocol: TCP
  - containerPort: 30443  # Istio ingress gateway NodePort (HTTPS)
    hostPort: 443
    protocol: TCP
```

### Istio Ingress Gateway 서비스

Istio ingress gateway를 NodePort로 노출:

```bash
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort","ports":[{"name":"http2","port":80,"targetPort":8080,"nodePort":30080},{"name":"https","port":443,"targetPort":8443,"nodePort":30443}]}}'
```

또는 별도 YAML 파일로 관리:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  type: NodePort
  selector:
    istio: ingressgateway
  ports:
  - name: http2
    port: 80
    targetPort: 8080
    nodePort: 30080
  - name: https
    port: 443
    targetPort: 8443
    nodePort: 30443
```

## 트래픽 흐름

```
사용자 (localhost:80)
  ↓
Kind Host 포트 (80)
  ↓
Kind Container 포트 (30080)
  ↓
Istio Ingress Gateway (istio-system:80 → 8080)
  ↓
Istio Gateway (dailyfeed-gateway)
  ↓
VirtualService (dailyfeed-frontend)
  ↓
Frontend Service (dailyfeed-frontend:3000)
  ↓
Frontend Pod (컨테이너 포트 3000)
```

## 고급 기능 활용

### 1. 카나리 배포

VirtualService에서 트래픽을 버전별로 분할:

```yaml
http:
- match:
  - uri:
      prefix: /
  route:
  - destination:
      host: dailyfeed-frontend
      subset: v1
    weight: 90
  - destination:
      host: dailyfeed-frontend
      subset: v2
    weight: 10
```

### 2. 헤더 기반 라우팅

특정 헤더를 가진 요청을 다른 버전으로 라우팅:

```yaml
http:
- match:
  - headers:
      x-version:
        exact: "beta"
  route:
  - destination:
      host: dailyfeed-frontend
      subset: v2
- route:
  - destination:
      host: dailyfeed-frontend
      subset: v1
```

### 3. URL Rewrite

```yaml
http:
- match:
  - uri:
      prefix: /old-path
  rewrite:
    uri: /new-path
  route:
  - destination:
      host: dailyfeed-frontend
```

## 문제 해결

### Gateway가 작동하지 않는 경우

1. Istio ingress gateway 로그 확인:
```bash
kubectl logs -n istio-system -l istio=ingressgateway
```

2. Gateway 및 VirtualService 상태 확인:
```bash
kubectl describe gateway dailyfeed-gateway -n dailyfeed
kubectl describe virtualservice dailyfeed-frontend -n dailyfeed
```

3. Istio 구성 확인:
```bash
istioctl analyze -n dailyfeed
```

### 서비스 연결 안 되는 경우

1. 서비스 존재 여부 확인:
```bash
kubectl get svc dailyfeed-frontend -n dailyfeed
```

2. Endpoint 확인:
```bash
kubectl get endpoints dailyfeed-frontend -n dailyfeed
```

3. Pod가 정상 실행 중인지 확인:
```bash
kubectl get pods -n dailyfeed -l app=dailyfeed-frontend
```

## 참고 자료

- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [Kind Ingress](https://kind.sigs.k8s.io/docs/user/ingress/)

## 마이그레이션 체크리스트

- [ ] Istio 설치 확인
- [ ] namespace에 istio-injection 라벨 추가
- [ ] Gateway 리소스 배포
- [ ] VirtualService 리소스 배포
- [ ] Istio ingress gateway를 NodePort로 노출
- [ ] Kind 클러스터 포트 매핑 확인
- [ ] 트래픽 라우팅 테스트
- [ ] 기존 Kubernetes Ingress 제거
- [ ] 모니터링 설정 (Kiali, Grafana 등)
