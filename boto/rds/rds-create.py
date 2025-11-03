# create_rds_free_tier.py
import boto3
import sys

def create_rds_free_tier(
    db_instance_identifier='my-dev-db',
    master_username='admin',
    master_password='YourSecurePassword123!',
    db_name='mydb'
):
    """
    RDS 프리티어 인스턴스 생성
    
    프리티어 조건:
    - db.t2.micro 또는 db.t3.micro (750시간/월 무료)
    - 20GB 스토리지까지 무료
    - Single-AZ
    """
    
    rds = boto3.client('rds', region_name='ap-northeast-2')
    
    try:
        response = rds.create_db_instance(
            # 인스턴스 식별자 (고유해야 함)
            DBInstanceIdentifier=db_instance_identifier,
            
            # 인스턴스 클래스 (프리티어)
            DBInstanceClass='db.t3.micro',
            
            # 엔진 선택
            Engine='mysql',
            EngineVersion='8.0.35',
            
            # 마스터 사용자 정보
            MasterUsername=master_username,
            MasterUserPassword=master_password,
            
            # 초기 데이터베이스 이름
            DBName=db_name,
            
            # 스토리지 설정 (프리티어: 20GB까지 무료)
            AllocatedStorage=20,
            StorageType='gp3',  # gp2보다 gp3가 더 저렴
            
            # 가용성 (프리티어는 Single-AZ만)
            MultiAZ=False,
            
            # 백업 설정
            BackupRetentionPeriod=7,  # 7일간 백업 보관
            PreferredBackupWindow='03:00-04:00',  # UTC 기준
            
            # 유지보수 윈도우
            PreferredMaintenanceWindow='mon:04:00-mon:05:00',
            
            # 퍼블릭 액세스
            PubliclyAccessible=True,
            
            # VPC 보안 그룹 (나중에 설정)
            VpcSecurityGroupIds=[],
            
            # 모니터링
            MonitoringInterval=0,  # 기본 모니터링 (무료)
            
            # 자동 마이너 버전 업그레이드
            AutoMinorVersionUpgrade=True,
            
            # 삭제 방지
            DeletionProtection=False,
            
            # 태그
            Tags=[
                {'Key': 'Environment', 'Value': 'development'},
                {'Key': 'AutoShutdown', 'Value': 'true'},
                {'Key': 'Project', 'Value': 'my-project'}
            ]
        )
        
        print(f"✅ RDS 인스턴스 생성 시작: {db_instance_identifier}")
        print(f"   상태: {response['DBInstance']['DBInstanceStatus']}")
        print(f"   엔드포인트는 5-10분 후 사용 가능합니다.")
        print(f"\n   생성 진행 상황 확인:")
        print(f"   aws rds describe-db-instances --db-instance-identifier {db_instance_identifier}")
        
        return response
        
    except rds.exceptions.DBInstanceAlreadyExistsFault:
        print(f"❌ 오류: {db_instance_identifier} 인스턴스가 이미 존재합니다.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    create_rds_free_tier(
        db_instance_identifier='my-dev-db',
        master_username='admin',
        master_password='ChangeThisPassword123!',
        db_name='mydb'
    )