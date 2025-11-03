# create_rds_with_sg.py
import boto3

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
    except rds.exceptions.DBInstanceAlreadyExistsFault:
        print(f"ℹ️  RDS 인스턴스가 이미 존재: dailyfeed-dev")

if __name__ == '__main__':
    create_rds_with_security_group('dailyfeed-rds-dev-sg')