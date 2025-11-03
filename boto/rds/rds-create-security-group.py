# create_security_group.py
import boto3

def create_rds_security_group(group_name):
    """RDS용 보안 그룹 생성"""
    ec2 = boto3.client('ec2', region_name='ap-northeast-2')
    
    # 기본 VPC ID 가져오기
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'isDefault', 'Values': ['true']}])
    
    if not vpcs['Vpcs']:
        print("❌ 기본 VPC를 찾을 수 없습니다.")
        return None
    
    vpc_id = vpcs['Vpcs'][0]['VpcId']
    print(f"✅ VPC ID: {vpc_id}")
    
    try:
        # 보안 그룹 생성
        response = ec2.create_security_group(
            GroupName=group_name,
            Description='Security group for RDS MySQL',
            VpcId=vpc_id
        )
        
        security_group_id = response['GroupId']
        print(f"✅ 보안 그룹 생성: {security_group_id}")
        
        # MySQL 포트 (3306) 인바운드 규칙 추가
        # ⚠️ 개발용: 0.0.0.0/0 허용 (프로덕션에서는 IP 제한 필요!)
        ec2.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 3306,
                    'ToPort': 3306,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'MySQL from anywhere'}]
                }
            ]
        )
        print(f"✅ 인바운드 규칙 추가: MySQL (3306)")
        
        return security_group_id
        
    except ec2.exceptions.ClientError as e:
        if 'InvalidGroup.Duplicate' in str(e):
            # 이미 존재하는 경우
            sgs = ec2.describe_security_groups(
                Filters=[
                    {'Name': 'group-name', 'Values': ['dailyfeed-rds-dev-sg']},
                    {'Name': 'vpc-id', 'Values': [vpc_id]}
                ]
            )
            sg_id = sgs['SecurityGroups'][0]['GroupId']
            print(f"ℹ️  기존 보안 그룹 사용: {sg_id}")
            return sg_id
        raise

if __name__ == '__main__':
    sg_id = create_rds_security_group('dailyfeed-rds-dev-sg')
    print(f"\n보안 그룹 ID를 RDS 생성 시 사용하세요: {sg_id}")