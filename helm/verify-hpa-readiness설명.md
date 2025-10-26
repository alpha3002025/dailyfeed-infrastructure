dailyfeed-infrastructure/helm/verify-hpa-readiness.sh


1. 생성된 파일들

/dailyfeed-infrastructure/helm/install-metrics-server.sh

- Kind 클러스터에 최적화된 metrics-server 설치 스크립트
- --kubelet-insecure-tls: Kind의 자체 서명 인증서 문제 해결
- --kubelet-preferred-address-types: Kind 환경의 내부 IP 사용 설정
- 자동으로 pod 준비 상태 대기 및 확인

/dailyfeed-infrastructure/helm/verify-hpa-readiness.sh

- HPA 준비 상태 종합 검증 스크립트
- Node/Pod metrics 수집 확인
- HPA 샘플 YAML 생성 (/tmp/sample-hpa.yaml)
- HPA 사용 가이드 제공

2. 수정된 파일

/dailyfeed-infrastructure/helm/1-install-essential-local.sh:64-66

- Istio 설치 후 metrics-server를 자동으로 설치하도록 추가

3. 사용 방법

# 전체 인프라 + 앱 설치 (metrics-server 포함)
./local-install-infra-and-app.sh test-20251025-1

# HPA 준비 상태 확인
cd dailyfeed-infrastructure/helm
source verify-hpa-readiness.sh

# Node/Pod 메트릭 확인 (설치 후 ~1분 대기 필요)
kubectl top nodes
kubectl top pods -n dailyfeed

4. HPA 적용 예시

검증 스크립트가 생성하는 샘플 HPA 설정:
- CPU 사용률 70% 도달 시 스케일 아웃
- Memory 사용률 80% 도달 시 스케일 아웃
- 최소 2개, 최대 10개 replica
- 점진적 스케일 다운 (300초 안정화 기간)
- 빠른 스케일 업 (즉시 반응)

5. 주의사항

1. 메트릭 수집 지연: metrics-server 설치 후 약 1분간 메트릭 수집 대기 필요
2. 리소스 요청 필수: HPA가 작동하려면 Deployment의 Pod에 resources.requests 설정 필수
3. Kind 전용 설정: 프로덕션 환경에서는 --kubelet-insecure-tls 제거 필요

이제 ./local-install-infra-and-app.sh test-20251025-1 실행 시 metrics-server가 자동으로 설치되어 HPA를 바로 사용할 수 있습니다!



