# Bitnami 저장소 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# MySQL 설치
helm install mysql bitnami/mysql \
  --namespace infra \
  --set auth.rootPassword="hitEnter$$$" \
  --set auth.username="dailyfeed" \
  --set auth.password="hitEnter$$$" \
  --set auth.database="dailyfeed" \
  --set primary.service.ports.mysql=3306