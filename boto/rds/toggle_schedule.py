# toggle_schedule.py
import boto3

def toggle_schedule(enable=True):
    """스케줄 활성화/비활성화"""
    events = boto3.client('events', region_name='ap-northeast-2')
    
    action = '활성화' if enable else '비활성화'
    
    for rule_name in ['RDSScheduler-Start-9AM', 'RDSScheduler-Stop-6PM']:
        try:
            if enable:
                events.enable_rule(Name=rule_name)
            else:
                events.disable_rule(Name=rule_name)
            print(f"✅ {rule_name} {action}")
        except Exception as e:
            print(f"❌ {rule_name} {action} 실패: {e}")

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1:
        enable = sys.argv[1].lower() == 'enable'
    else:
        enable = False  # 기본값: 비활성화
    
    toggle_schedule(enable)

# 사용법:
# python toggle_schedule.py disable  # 비활성화
# python toggle_schedule.py enable   # 활성화