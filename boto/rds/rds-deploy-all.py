# deploy_all.py
import boto3
import json
import time
import zipfile
import os
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

class RDSSchedulerDeployer:
    def __init__(self, db_instance_id='dailyfeed-dev', db_name='dailyfeed', region='ap-northeast-2'):
        self.db_instance_id = db_instance_id
        self.db_name = db_name
        self.region = region
        self.rds = boto3.client('rds', region_name=region)
        self.iam = boto3.client('iam')
        self.lambda_client = boto3.client('lambda', region_name=region)
        self.events = boto3.client('events', region_name=region)
        self.sts = boto3.client('sts')
        self.ec2 = boto3.client('ec2', region_name=region)
        
    def step1_create_rds(self, master_password, group_name):
        """1단계: RDS 프리티어 생성"""
        print("\n" + "="*60)
        print("1단계: RDS 프리티어 인스턴스 생성")
        print("="*60)
        
        # 보안 그룹 생성
        vpcs = self.ec2.describe_vpcs(
            Filters=[{'Name': 'isDefault', 'Values': ['true']}]
        )
        vpc_id = vpcs['Vpcs'][0]['VpcId']
        
        try:
            sg_response = self.ec2.create_security_group(
                GroupName=group_name,
                Description='RDS MySQL Security Group',
                VpcId=vpc_id
            )
            sg_id = sg_response['GroupId']
            
            self.ec2.authorize_security_group_ingress(
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
            sgs = self.ec2.describe_security_groups(
                Filters=[{'Name': 'group-name', 'Values': [group_name]}]
            )
            sg_id = sgs['SecurityGroups'][0]['GroupId']
            print(f"ℹ️  기존 보안 그룹 사용: {sg_id}")
        
        # RDS 생성
        try:
            self.rds.create_db_instance(
                DBInstanceIdentifier=self.db_instance_id,
                DBInstanceClass='db.t3.micro',
                Engine='mysql',
                EngineVersion='8.0.43',
                MasterUsername='admin',
                MasterUserPassword=master_password,
                DBName=self.db_name,
                AllocatedStorage=20,
                StorageType='gp3',
                MultiAZ=False,
                BackupRetentionPeriod=7,
                PubliclyAccessible=True,
                VpcSecurityGroupIds=[sg_id],
                Tags=[
                    {'Key': 'Environment', 'Value': 'development'},
                    {'Key': 'AutoShutdown', 'Value': 'true'}
                ]
            )
            print(f"✅ RDS 생성 시작: {self.db_instance_id}")
            print("   ⏳ 5-10분 후 사용 가능")

            # RDS 인스턴스가 사용 가능해질 때까지 대기
            print(f"\n⏳ RDS 인스턴스가 사용 가능해질 때까지 대기 중...")
            waiter = self.rds.get_waiter('db_instance_available')
            waiter.wait(
                DBInstanceIdentifier=self.db_instance_id,
                WaiterConfig={'Delay': 30, 'MaxAttempts': 40}
            )

            # 엔드포인트 가져오기
            db_response = self.rds.describe_db_instances(DBInstanceIdentifier=self.db_instance_id)
            endpoint = db_response['DBInstances'][0]['Endpoint']['Address']
            print(f"✅ RDS 인스턴스 사용 가능: {endpoint}")

            # 데이터베이스 사용자 생성
            create_database_user(endpoint, 'admin', master_password, self.db_name)

        except self.rds.exceptions.DBInstanceAlreadyExistsFault:
            print(f"ℹ️  RDS 이미 존재: {self.db_instance_id}")
    
    def step2_create_lambda_role(self):
        """2단계: Lambda IAM 역할 생성"""
        print("\n" + "="*60)
        print("2단계: Lambda IAM 역할 생성")
        print("="*60)
        
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }
        
        try:
            response = self.iam.create_role(
                RoleName='RDSSchedulerLambdaRole',
                AssumeRolePolicyDocument=json.dumps(trust_policy)
            )
            role_arn = response['Role']['Arn']
            print(f"✅ IAM 역할 생성: {role_arn}")
        except self.iam.exceptions.EntityAlreadyExistsException:
            response = self.iam.get_role(RoleName='RDSSchedulerLambdaRole')
            role_arn = response['Role']['Arn']
            print(f"ℹ️  기존 역할 사용: {role_arn}")
        
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "rds:DescribeDBInstances",
                        "rds:StartDBInstance",
                        "rds:StopDBInstance"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource": "*"
                }
            ]
        }
        
        self.iam.put_role_policy(
            RoleName='RDSSchedulerLambdaRole',
            PolicyName='RDSSchedulerPolicy',
            PolicyDocument=json.dumps(policy)
        )
        print("✅ IAM 정책 연결")
        
        print("⏳ IAM 역할 전파 대기 (10초)...")
        time.sleep(10)
        
        return role_arn
    
    def step3_create_lambda_function(self, role_arn):
        """3단계: Lambda 함수 생성"""
        print("\n" + "="*60)
        print("3단계: Lambda 함수 생성")
        print("="*60)
        
        # Lambda 코드
        lambda_code = '''import boto3
import os
import json
from datetime import datetime

DB_INSTANCE_ID = os.environ['DB_INSTANCE_ID']
# AWS_REGION은 Lambda 예약 환경 변수이므로 boto3가 자동으로 감지
rds = boto3.client('rds')

def lambda_handler(event, context):
    action = event.get('action', 'status')
    print(f"Action: {action}, Instance: {DB_INSTANCE_ID}")
    
    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=DB_INSTANCE_ID)
        status = response['DBInstances'][0]['DBInstanceStatus']
        
        if action == 'start' and status == 'stopped':
            rds.start_db_instance(DBInstanceIdentifier=DB_INSTANCE_ID)
            return {'statusCode': 200, 'body': 'Starting'}
        elif action == 'stop' and status == 'available':
            rds.stop_db_instance(DBInstanceIdentifier=DB_INSTANCE_ID)
            return {'statusCode': 200, 'body': 'Stopping'}
        else:
            return {'statusCode': 200, 'body': f'Status: {status}'}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
'''
        
        # ZIP 생성
        with zipfile.ZipFile('lambda.zip', 'w') as zf:
            zf.writestr('lambda_function.py', lambda_code)
        
        with open('lambda.zip', 'rb') as f:
            zip_content = f.read()
        
        try:
            response = self.lambda_client.create_function(
                FunctionName='RDSScheduler',
                Runtime='python3.11',
                Role=role_arn,
                Handler='lambda_function.lambda_handler',
                Code={'ZipFile': zip_content},
                Timeout=60,
                MemorySize=128,
                Environment={
                    'Variables': {
                        'DB_INSTANCE_ID': self.db_instance_id
                        # AWS_REGION은 Lambda 예약 변수이므로 제외
                    }
                }
            )
            function_arn = response['FunctionArn']
            print(f"✅ Lambda 함수 생성: {function_arn}")
        except self.lambda_client.exceptions.ResourceConflictException:
            self.lambda_client.update_function_code(
                FunctionName='RDSScheduler',
                ZipFile=zip_content
            )
            response = self.lambda_client.get_function(FunctionName='RDSScheduler')
            function_arn = response['Configuration']['FunctionArn']
            print(f"✅ Lambda 함수 업데이트: {function_arn}")
        
        os.remove('lambda.zip')
        return function_arn
    
    def step4_create_eventbridge_rules(self, lambda_arn):
        """4단계: EventBridge 스케줄 생성"""
        print("\n" + "="*60)
        print("4단계: EventBridge 스케줄 설정")
        print("="*60)
        
        account_id = self.sts.get_caller_identity()['Account']
        
        # 시작 규칙
        self.events.put_rule(
            Name='RDSScheduler-Start-9AM',
            ScheduleExpression='cron(0 0 * * ? *)',
            State='ENABLED'
        )
        print("✅ 시작 규칙 생성: 매일 오전 9시")
        
        # 중지 규칙
        self.events.put_rule(
            Name='RDSScheduler-Stop-6PM',
            ScheduleExpression='cron(0 9 * * ? *)',
            State='ENABLED'
        )
        print("✅ 중지 규칙 생성: 매일 오후 6시")
        
        # Lambda 권한
        for rule_name, statement_id in [
            ('RDSScheduler-Start-9AM', 'AllowEventBridgeStart'),
            ('RDSScheduler-Stop-6PM', 'AllowEventBridgeStop')
        ]:
            try:
                self.lambda_client.add_permission(
                    FunctionName='RDSScheduler',
                    StatementId=statement_id,
                    Action='lambda:InvokeFunction',
                    Principal='events.amazonaws.com',
                    SourceArn=f'arn:aws:events:{self.region}:{account_id}:rule/{rule_name}'
                )
            except:
                pass
        
        print("✅ Lambda 권한 부여")
        
        # 타겟 연결
        self.events.put_targets(
            Rule='RDSScheduler-Start-9AM',
            Targets=[{
                'Id': '1',
                'Arn': lambda_arn,
                'Input': json.dumps({'action': 'start'})
            }]
        )
        
        self.events.put_targets(
            Rule='RDSScheduler-Stop-6PM',
            Targets=[{
                'Id': '1',
                'Arn': lambda_arn,
                'Input': json.dumps({'action': 'stop'})
            }]
        )
        print("✅ EventBridge 타겟 연결")
    
    def deploy(self, master_password):
        """전체 배포"""
        print("\n" + "🚀 "*20)
        print("RDS 자동 스케줄러 배포 시작")
        print("🚀 "*20)
        
        self.step1_create_rds(master_password, 'dailyfeed-rds-dev-sg')
        role_arn = self.step2_create_lambda_role()
        lambda_arn = self.step3_create_lambda_function(role_arn)
        self.step4_create_eventbridge_rules(lambda_arn)
        
        print("\n" + "✅ "*20)
        print("배포 완료!")
        print("✅ "*20)
        print(f"\n📊 설정 요약:")
        print(f"   RDS: {self.db_instance_id}")
        print(f"   시작: 매일 오전 9시 (KST)")
        print(f"   중지: 매일 오후 6시 (KST)")
        print(f"   가동: 하루 9시간")
        print(f"   예상 비용: $5-7/월 (75% 절감)")

if __name__ == '__main__':
    deployer = RDSSchedulerDeployer(
        db_instance_id='dailyfeed-dev',
        db_name='dailyfeed',
        region='ap-northeast-2'
    )
    
    deployer.deploy(master_password='hitEnter###')