# rds-user-create.py
import boto3
import pymysql
import sys

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
        sys.exit(1)
    except Exception as e:
        print(f"❌ 연결 오류: {str(e)}")
        print(f"   보안 그룹 설정을 확인하세요.")
        sys.exit(1)

def get_rds_endpoint(db_instance_identifier, region='ap-northeast-2'):
    """
    RDS 인스턴스의 엔드포인트 가져오기
    """
    print(f"🔍 RDS 인스턴스 정보 조회 중: {db_instance_identifier}")

    rds = boto3.client('rds', region_name=region)

    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=db_instance_identifier)
        db_instance = response['DBInstances'][0]

        status = db_instance['DBInstanceStatus']
        if status != 'available':
            print(f"⚠️  RDS 인스턴스 상태: {status}")
            print(f"   인스턴스가 'available' 상태가 아닙니다.")
            sys.exit(1)

        endpoint = db_instance['Endpoint']['Address']
        print(f"✅ 엔드포인트 확인: {endpoint}")
        return endpoint

    except rds.exceptions.DBInstanceNotFoundFault:
        print(f"❌ RDS 인스턴스를 찾을 수 없습니다: {db_instance_identifier}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    # RDS 인스턴스 설정
    db_instance_identifier = 'dailyfeed-dev'
    db_name = 'dailyfeed'
    master_username = 'admin'
    master_password = 'hitEnter###'

    # 새로 생성할 사용자 정보
    new_username = 'dailyfeed'
    new_password = 'hitEnter###'

    print("="*60)
    print("RDS 데이터베이스 사용자 생성 스크립트")
    print("="*60)

    # RDS 엔드포인트 가져오기
    endpoint = get_rds_endpoint(db_instance_identifier)

    # 데이터베이스 사용자 생성
    create_database_user(
        endpoint=endpoint,
        master_username=master_username,
        master_password=master_password,
        db_name=db_name,
        new_username=new_username,
        new_password=new_password
    )

    print("\n" + "="*60)
    print("사용자 생성 완료!")
    print("="*60)
