# MySQL & Redis 연결 테스트 및 트러블슈팅 가이드

Kind 클러스터의 MySQL과 Redis 서비스 연결을 테스트하고 문제를 해결하기 위한 명령어 모음입니다.

## 목차
- [서비스 상태 확인](#서비스-상태-확인)
- [Pod 상태 및 로그 확인](#pod-상태-및-로그-확인)
- [연결 테스트](#연결-테스트)
- [MySQL 접속 테스트](#mysql-접속-테스트)
- [포트 및 네트워크 확인](#포트-및-네트워크-확인)
- [NodePort 서비스 관리](#nodeport-서비스-관리)
- [IntelliJ Database 연결 설정](#intellij-database-연결-설정)

---

## 서비스 상태 확인

### 모든 서비스 확인
```bash
kubectl get svc -n infra
```

### MySQL 및 Redis 서비스만 확인
```bash
kubectl get svc -n infra | grep -E "NAME|mysql|redis"
```

### NodePort 서비스 상세 정보
```bash
kubectl describe svc mysql-nodeport -n infra
kubectl describe svc redis-nodeport -n infra
```

### 서비스 엔드포인트 확인
```bash
kubectl describe svc mysql-nodeport -n infra | grep -A 5 "Endpoints"
kubectl describe svc redis-nodeport -n infra | grep -A 5 "Endpoints"
```

---

## Pod 상태 및 로그 확인

### Pod 상태 확인
```bash
# 모든 인프라 Pod 확인
kubectl get pods -n infra

# MySQL, Redis Pod만 확인
kubectl get pods -n infra | grep -E "NAME|mysql|redis"

# 상세 정보와 함께 확인 (IP, Node 등)
kubectl get pods -n infra -o wide | grep -E "NAME|mysql|redis"
```

### MySQL Pod 로그 확인
```bash
# 최근 30줄
kubectl logs -n infra $(kubectl get pods -n infra -l app=mysql -o jsonpath='{.items[0].metadata.name}') --tail=30

# 실시간 로그
kubectl logs -n infra $(kubectl get pods -n infra -l app=mysql -o jsonpath='{.items[0].metadata.name}') -f

# 모든 로그
kubectl logs -n infra $(kubectl get pods -n infra -l app=mysql -o jsonpath='{.items[0].metadata.name}')
```

### Redis Pod 로그 확인
```bash
kubectl logs -n infra redis-0 --tail=30
kubectl logs -n infra redis-0 -f
```

---

## 연결 테스트

### 로컬호스트 포트 연결 테스트
```bash
# MySQL 포트 테스트
nc -zv localhost 3306

# Redis 포트 테스트
nc -zv localhost 6379

# 둘 다 테스트
nc -zv localhost 3306 && nc -zv localhost 6379
```

### 포트가 열려있는지 확인
```bash
# MySQL 포트 확인
lsof -i :3306

# Redis 포트 확인
lsof -i :6379

# 둘 다 확인
lsof -i :3306 -i :6379
```

---

## MySQL 접속 테스트

### Pod 내부에서 MySQL 접속
```bash
# dailyfeed 사용자로 접속 테스트
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### dailyfeed -e "SELECT 1 as connection_test;"

# 데이터베이스 목록 확인
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### -e "SHOW DATABASES;"

# dailyfeed 데이터베이스의 테이블 확인
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### dailyfeed -e "SHOW TABLES;"
```

### Pod에 직접 접속하여 MySQL 사용
```bash
# Pod 쉘 접속
kubectl exec -it -n infra deployment/mysql -- bash

# 접속 후 MySQL 실행
mysql -u dailyfeed -phitEnter### dailyfeed
```

### Root 계정으로 접속 (관리 작업용)
```bash
kubectl exec -n infra deployment/mysql -- mysql -u root -prootpassword -e "SELECT User, Host FROM mysql.user;"
```

---

## 포트 및 네트워크 확인

### Kind 컨테이너 포트 매핑 확인
```bash
# 간단히 확인
docker ps | grep -E "istio-cluster|kind"

# 포트 매핑 상세 확인
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "NAME|istio"
```

예상 출력:
```
0.0.0.0:3306->30306/tcp   # MySQL
0.0.0.0:6379->30379/tcp   # Redis
```

### 클러스터 노드 확인
```bash
kubectl get nodes -o wide
```

### 네트워크 정책 확인
```bash
kubectl get networkpolicies -n infra
```

---

## NodePort 서비스 관리

### NodePort 서비스 생성
```bash
kubectl apply -f /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-infrastructure/kind/nodeport/mysql-nodeport.yaml
kubectl apply -f /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-infrastructure/kind/nodeport/redis-nodeport.yaml
```

### NodePort 서비스 삭제
```bash
kubectl delete svc mysql-nodeport -n infra
kubectl delete svc redis-nodeport -n infra
```

### NodePort 서비스 재생성 (클러스터 재생성 후)
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-infrastructure/kind/nodeport
kubectl apply -f mysql-nodeport.yaml
kubectl apply -f redis-nodeport.yaml
```

---

## Port Forward (대안 방법)

NodePort가 작동하지 않을 때 임시로 사용할 수 있는 방법입니다.

### MySQL Port Forward
```bash
# 백그라운드로 실행
kubectl port-forward -n infra svc/mysql 3306:3306 &

# 다른 포트로 실행
kubectl port-forward -n infra svc/mysql 13306:3306 &
```

### Redis Port Forward
```bash
kubectl port-forward -n infra svc/redis-master 6379:6379 &
```

### Port Forward 종료
```bash
# 프로세스 확인
ps aux | grep "port-forward"

# 프로세스 종료
kill <PID>

# 모든 port-forward 종료
pkill -f "kubectl port-forward"
```

---

## IntelliJ Database 연결 설정

### 기본 설정
```
Host: localhost (또는 127.0.0.1)
Port: 3306
Database: dailyfeed
User: dailyfeed
Password: hitEnter###
```

### JDBC URL (권장)
```
jdbc:mysql://localhost:3306/dailyfeed?allowPublicKeyRetrieval=true&useSSL=false
```

### 연결 테스트 SQL
```sql
SELECT 1 as connection_test;
SHOW DATABASES;
USE dailyfeed;
SHOW TABLES;
```

---

## 문제 해결 체크리스트

### 1. 서비스가 실행 중인지 확인
```bash
kubectl get svc -n infra | grep -E "mysql|redis"
```
- NodePort 서비스가 존재하는지 확인
- NodePort 번호가 30306 (MySQL), 30379 (Redis)인지 확인

### 2. Pod이 실행 중인지 확인
```bash
kubectl get pods -n infra | grep -E "mysql|redis"
```
- STATUS가 `Running`인지 확인
- READY가 `1/1`인지 확인

### 3. 포트 매핑이 올바른지 확인
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep istio
```
- `0.0.0.0:3306->30306/tcp` 매핑 확인
- `0.0.0.0:6379->30379/tcp` 매핑 확인

### 4. 포트가 접근 가능한지 확인
```bash
nc -zv localhost 3306
nc -zv localhost 6379
```
- `Connection to localhost port 3306 [tcp/mysql] succeeded!` 메시지 확인

### 5. MySQL 인증 정보 확인
```bash
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### -e "SELECT 1;"
```
- 정상적으로 `1` 결과가 나오는지 확인

---

## 일반적인 에러 및 해결 방법

### "Connection refused"
**원인**: NodePort 서비스가 없거나 포트 매핑이 안 됨

**해결**:
```bash
# NodePort 서비스 확인
kubectl get svc -n infra | grep nodeport

# 없으면 생성
kubectl apply -f /path/to/mysql-nodeport.yaml
kubectl apply -f /path/to/redis-nodeport.yaml
```

### "Communications link failure"
**원인**: MySQL Pod이 실행 중이 아니거나 네트워크 문제

**해결**:
```bash
# Pod 상태 확인
kubectl get pods -n infra | grep mysql

# 로그 확인
kubectl logs -n infra deployment/mysql --tail=50
```

### "Access denied for user"
**원인**: 잘못된 인증 정보

**해결**:
```bash
# Pod 내부에서 직접 테스트
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### -e "SELECT 1;"

# 사용자 목록 확인
kubectl exec -n infra deployment/mysql -- mysql -u root -prootpassword -e "SELECT User, Host FROM mysql.user;"
```

### "Unknown database 'dailyfeed'"
**원인**: 데이터베이스가 생성되지 않음

**해결**:
```bash
# 데이터베이스 확인
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### -e "SHOW DATABASES;"

# 없으면 생성
kubectl exec -n infra deployment/mysql -- mysql -u root -prootpassword -e "CREATE DATABASE dailyfeed;"
```

---

## 클러스터 재생성 후 체크리스트

Kind 클러스터를 재생성한 후에는 다음 단계를 순서대로 실행하세요:

```bash
# 1. 클러스터 상태 확인
kubectl get nodes
kubectl get pods -n infra

# 2. NodePort 서비스 생성
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-infrastructure/kind/nodeport
kubectl apply -f mysql-nodeport.yaml
kubectl apply -f redis-nodeport.yaml

# 3. 서비스 확인
kubectl get svc -n infra | grep nodeport

# 4. 포트 매핑 확인
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep istio

# 5. 연결 테스트
nc -zv localhost 3306
nc -zv localhost 6379

# 6. MySQL 접속 테스트
kubectl exec -n infra deployment/mysql -- mysql -u dailyfeed -phitEnter### -e "SELECT 1;"
```

---

## 추가 유용한 명령어

### ConfigMap 및 Secret 확인
```bash
# MySQL 관련 ConfigMap 확인
kubectl get configmap -n infra | grep mysql
kubectl describe configmap mysql-init-script -n infra

# MySQL Secret 확인
kubectl get secret -n infra | grep mysql
kubectl get secret mysql -n infra -o yaml
```

### 리소스 사용량 확인
```bash
# Pod 리소스 사용량
kubectl top pods -n infra

# Node 리소스 사용량
kubectl top nodes
```

### 이벤트 확인
```bash
# 최근 이벤트 확인
kubectl get events -n infra --sort-by='.lastTimestamp'

# MySQL 관련 이벤트만
kubectl get events -n infra --field-selector involvedObject.name=mysql-xxx
```

---

## 참고 문서

- [Kind 포트 매핑 문서](https://kind.sigs.k8s.io/docs/user/configuration/#extra-port-mappings)
- [Kubernetes Service 문서](https://kubernetes.io/docs/concepts/services-networking/service/)
- [MySQL 8.0 문서](https://dev.mysql.com/doc/refman/8.0/en/)