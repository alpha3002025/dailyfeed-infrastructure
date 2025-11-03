# RDS 설치/삭제 script

# 전체 설치
```bash
# python rds-deploy-all.py
```

# RDS, 보안그룹만 설치
```bash
# python rds-create-with-sg.py
```

# 수동 생성/중지
```bash
# python rds-create-not-auto.py start
# python rds-create-not-auto.py stop
```

# 스케쥴링 비활성화
```bash
# python toggle_schedule.py disable  # 비활성화
# python toggle_schedule.py enable   # 활성화
```

# cleanup
```bash
# python cleanup-all.py
```

# 개별 삭제 명령어
```bash
# EventBridge 규칙 삭제
aws events remove-targets \
    --rule RDSScheduler-Start-9AM \
    --ids 1 \
    --region ap-northeast-2

aws events delete-rule \
    --name RDSScheduler-Start-9AM \
    --region ap-northeast-2

# Lambda 함수 삭제
aws lambda delete-function \
    --function-name RDSScheduler \
    --region ap-northeast-2

# RDS 삭제
aws rds delete-db-instance \
    --db-instance-identifier dailyfeed-dev \
    --skip-final-snapshot \
    --region ap-northeast-2

# IAM 역할 삭제
aws iam delete-role-policy \
    --role-name RDSSchedulerLambdaRole \
    --policy-name RDSSchedulerPolicy

aws iam delete-role \
    --role-name RDSSchedulerLambdaRole

# 보안 그룹 삭제 (RDS 삭제 완료 후)
aws ec2 delete-security-group \
    --group-name dailyfeed-rds-dev-sg \
    --region ap-northeast-2
```