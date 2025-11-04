# create_rds_with_sg.py
import boto3
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

def create_rds_with_security_group(group_name):
    """보안 그룹과 함께 RDS 생성"""
    
    # 1. 보안 그룹 생성
    ec2 = boto3.client('ec2', region_name='ap-northeast-2')
    
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'isDefault', 'Values': ['true']}])
    vpc_id = vpcs['Vpcs'][0]['VpcId']
    
    try:
        sg_response = ec2.create_security_group(
            GroupName=group_name,
            Description='RDS MySQL Security Group',
            VpcId=vpc_id
        )
        sg_id = sg_response['GroupId']
        
        ec2.authorize_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[{
                'IpProtocol': 'tcp',
                'FromPort': 3306,
                'ToPort': 3306,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }]
        )
        print(f"✅ 보안 그룹 생성: {sg_id}")
    except:
        sgs = ec2.describe_security_groups(
            Filters=[{'Name': 'group-name', 'Values': [group_name]}]
        )
        sg_id = sgs['SecurityGroups'][0]['GroupId']
        print(f"ℹ️  기존 보안 그룹 사용: {sg_id}")
    
    # 2. RDS 생성
    rds = boto3.client('rds', region_name='ap-northeast-2')
    
    try:
        response = rds.create_db_instance(
            DBInstanceIdentifier='dailyfeed-dev',
            DBInstanceClass='db.t3.micro',
            Engine='mysql',
            EngineVersion='8.0.43',  # AWS RDS에서 사용 가능한 최신 8.0.x 버전
            MasterUsername='admin',
            MasterUserPassword='hitEnter###',
            DBName='dailyfeed',
            AllocatedStorage=20,
            StorageType='gp3',
            MultiAZ=False,
            BackupRetentionPeriod=7,
            PubliclyAccessible=True,
            VpcSecurityGroupIds=[sg_id],  # 보안 그룹 적용
            Tags=[
                {'Key': 'Environment', 'Value': 'development'},
                {'Key': 'AutoShutdown', 'Value': 'true'}
            ]
        )
        print(f"✅ RDS 생성 시작: dailyfeed-dev")
        print(f"   상태: {response['DBInstance']['DBInstanceStatus']}")

        # RDS 인스턴스가 사용 가능해질 때까지 대기
        print(f"\n⏳ RDS 인스턴스가 사용 가능해질 때까지 대기 중...")
        waiter = rds.get_waiter('db_instance_available')
        waiter.wait(
            DBInstanceIdentifier='dailyfeed-dev',
            WaiterConfig={'Delay': 30, 'MaxAttempts': 40}
        )

        # 엔드포인트 가져오기
        db_response = rds.describe_db_instances(DBInstanceIdentifier='dailyfeed-dev')
        endpoint = db_response['DBInstances'][0]['Endpoint']['Address']
        print(f"✅ RDS 인스턴스 사용 가능: {endpoint}")

        # 데이터베이스 사용자 생성
        create_database_user(endpoint, 'admin', 'hitEnter###', 'dailyfeed')

    except rds.exceptions.DBInstanceAlreadyExistsFault:
        print(f"ℹ️  RDS 인스턴스가 이미 존재: dailyfeed-dev")

if __name__ == '__main__':
    create_rds_with_security_group('dailyfeed-rds-dev-sg')