# create_rds_free_tier.py
import boto3
import sys
import time
import pymysql

def create_database_user(endpoint, master_username, master_password, db_name,
                        new_username='dailyfeed', new_password='hitEnter###'):
    """
    RDS 인스턴스에 새로운 데이터베이스 사용자 생성
    """
    print(f"\n🔐 데이터베이스 사용자 확인 및 생성 중...")

    try:
        # MySQL 연결
        connection = pymysql.connect(
            host=endpoint,
            user=master_username,
            password=master_password,
            database=db_name,
            connect_timeout=10
        )

        with connection.cursor() as cursor:
            # 사용자 존재 여부 확인
            cursor.execute(f"SELECT User FROM mysql.user WHERE User = '{new_username}' AND Host = '%'")
            user_exists = cursor.fetchone()

            if user_exists:
                print(f"ℹ️  사용자가 이미 존재합니다: {new_username}")
            else:
                # 사용자 생성
                cursor.execute(f"CREATE USER '{new_username}'@'%' IDENTIFIED BY '{new_password}'")
                print(f"✅ 사용자 생성: {new_username}")

            # 권한 부여 (모든 권한)
            cursor.execute(f"GRANT ALL PRIVILEGES ON {db_name}.* TO '{new_username}'@'%'")
            print(f"✅ 권한 부여: {db_name} 데이터베이스에 대한 모든 권한")

            # 권한 적용
            cursor.execute("FLUSH PRIVILEGES")
            print(f"✅ 권한 적용 완료")

        connection.commit()
        connection.close()

        print(f"\n📊 사용자 정보:")
        print(f"   사용자명: {new_username}")
        print(f"   비밀번호: {new_password}")
        print(f"   데이터베이스: {db_name}")
        print(f"   엔드포인트: {endpoint}")

    except pymysql.MySQLError as e:
        print(f"❌ 사용자 생성 실패: {str(e)}")
        print(f"   수동으로 사용자를 생성해야 할 수 있습니다.")
    except Exception as e:
        print(f"❌ 연결 오류: {str(e)}")
        print(f"   보안 그룹 설정을 확인하세요.")

def create_rds_free_tier(
    ## 초기 DB instance 이름 : my-dev-db, db 명: mydb
    db_instance_identifier='dailyfeed-dev',
    master_username='admin',
    master_password='hitEnter###',
    db_name='dailyfeed'
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
            EngineVersion='8.0.43',  # AWS RDS에서 사용 가능한 최신 8.0.x 버전
            
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

        # RDS 인스턴스가 사용 가능해질 때까지 대기
        print(f"\n⏳ RDS 인스턴스가 사용 가능해질 때까지 대기 중...")
        waiter = rds.get_waiter('db_instance_available')
        waiter.wait(
            DBInstanceIdentifier=db_instance_identifier,
            WaiterConfig={'Delay': 30, 'MaxAttempts': 40}
        )

        # 엔드포인트 가져오기
        db_response = rds.describe_db_instances(DBInstanceIdentifier=db_instance_identifier)
        endpoint = db_response['DBInstances'][0]['Endpoint']['Address']
        print(f"✅ RDS 인스턴스 사용 가능: {endpoint}")

        # 데이터베이스 사용자 생성
        create_database_user(endpoint, master_username, master_password, db_name)

        return response
        
    except rds.exceptions.DBInstanceAlreadyExistsFault:
        print(f"❌ 오류: {db_instance_identifier} 인스턴스가 이미 존재합니다.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    create_rds_free_tier(
        db_instance_identifier='dailyfeed-dev',
        master_username='admin',
        master_password='hitEnter###',
        db_name='dailyfeed'
    )