# manual_control.py
import boto3
import sys

def control_rds(action, db_instance_id='dailyfeed-dev'):
    """RDS 수동 시작/중지"""
    rds = boto3.client('rds', region_name='ap-northeast-2')
    
    try:
        response = rds.describe_db_instances(
            DBInstanceIdentifier=db_instance_id
        )
        status = response['DBInstances'][0]['DBInstanceStatus']
        print(f"현재 상태: {status}")
        
        if action == 'start':
            if status == 'stopped':
                rds.start_db_instance(DBInstanceIdentifier=db_instance_id)
                print(f"✅ RDS 시작 요청")
            else:
                print(f"⚠️  현재 상태({status})에서는 시작할 수 없음")
                
        elif action == 'stop':
            if status == 'available':
                rds.stop_db_instance(DBInstanceIdentifier=db_instance_id)
                print(f"✅ RDS 중지 요청")
            else:
                print(f"⚠️  현재 상태({status})에서는 중지할 수 없음")
                
    except Exception as e:
        print(f"❌ 오류: {e}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("사용법: python rds-create-not-auto.py [start|stop]")
        sys.exit(1)
    
    action = sys.argv[1].lower()
    control_rds(action)

# 사용법:
# python rds-create-not-auto.py start
# python rds-create-not-auto.py stop