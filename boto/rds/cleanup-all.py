# cleanup_all.py
import boto3
import time

def cleanup_all(db_instance_id='dailyfeed-dev'):
    """모든 리소스 삭제"""
    
    print("🗑️  리소스 정리 시작...\n")
    
    region = 'ap-northeast-2'
    rds = boto3.client('rds', region_name=region)
    lambda_client = boto3.client('lambda', region_name=region)
    events = boto3.client('events', region_name=region)
    iam = boto3.client('iam')
    ec2 = boto3.client('ec2', region_name=region)
    
    # 1. EventBridge 규칙 삭제
    print("1. EventBridge 규칙 삭제...")
    for rule_name in ['RDSScheduler-Start-9AM', 'RDSScheduler-Stop-6PM']:
        try:
            events.remove_targets(Rule=rule_name, Ids=['1'])
            events.delete_rule(Name=rule_name)
            print(f"   ✅ {rule_name} 삭제")
        except:
            print(f"   ⚠️  {rule_name} 없음")
    
    # 2. Lambda 함수 삭제
    print("\n2. Lambda 함수 삭제...")
    try:
        lambda_client.delete_function(FunctionName='RDSScheduler')
        print("   ✅ Lambda 함수 삭제")
    except:
        print("   ⚠️  Lambda 함수 없음")
    
    # 3. IAM 역할 삭제
    print("\n3. IAM 역할 삭제...")
    try:
        iam.delete_role_policy(
            RoleName='RDSSchedulerLambdaRole',
            PolicyName='RDSSchedulerPolicy'
        )
        iam.delete_role(RoleName='RDSSchedulerLambdaRole')
        print("   ✅ IAM 역할 삭제")
    except:
        print("   ⚠️  IAM 역할 없음")
    
    # 4. RDS 인스턴스 삭제
    print(f"\n4. RDS 인스턴스 삭제: {db_instance_id}...")
    try:
        rds.delete_db_instance(
            DBInstanceIdentifier=db_instance_id,
            SkipFinalSnapshot=True
        )
        print(f"   ✅ RDS 삭제 시작 (5-10분 소요)")
    except:
        print(f"   ⚠️  RDS 인스턴스 없음")
    
    # 5. 보안 그룹 삭제 (RDS 삭제 후 가능)
    print("\n5. 보안 그룹 정리...")
    print("   ℹ️  RDS 삭제 완료 후 수동으로 삭제하세요:")
    print("   aws ec2 delete-security-group --group-name dailyfeed-rds-dev-sg")
    
    print("\n✅ 정리 완료!")
    print("   RDS 삭제는 백그라운드에서 진행됩니다.")

if __name__ == '__main__':
    print("⚠️  경고: 모든 리소스가 삭제됩니다!")
    response = input("정말로 삭제하시겠습니까? (yes/no): ")
    
    if response.lower() == 'yes':
        cleanup_all('dailyfeed-dev')
    else:
        print("취소되었습니다.")