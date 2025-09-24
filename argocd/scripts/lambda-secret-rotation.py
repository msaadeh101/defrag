# lambda-secret-rotation.py
import json
import boto3
import base64
import requests
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Automated secret rotation for ArgoCD GitLab tokens
    """
    secrets_client = boto3.client('secretsmanager')
    
    secret_name = event['secret_name']
    rotation_days = event.get('rotation_days', 90)
    
    try:
        # Get current secret
        response = secrets_client.get_secret_value(SecretId=secret_name)
        current_secret = json.loads(response['SecretString'])
        
        # Generate new GitLab token (requires GitLab API integration)
        new_token = generate_new_gitlab_token(current_secret['username'])
        
        # Test new token
        if test_gitlab_token(new_token, current_secret['url']):
            # Update secret
            new_secret = current_secret.copy()
            new_secret['token'] = new_token
            new_secret['rotated_at'] = datetime.utcnow().isoformat()
            
            secrets_client.update_secret(
                SecretId=secret_name,
                SecretString=json.dumps(new_secret)
            )
            
            # Trigger ArgoCD secret refresh
            trigger_argocd_refresh()
            
            return {
                'statusCode': 200,
                'body': json.dumps(f'Successfully rotated secret {secret_name}')
            }
        else:
            raise Exception('New token validation failed')
            
    except Exception as e:
        # Send alert to SNS
        sns = boto3.client('sns')
        sns.publish(
            TopicArn='arn:aws:sns:us-west-2:ACCOUNT:argocd-alerts',
            Message=f'Secret rotation failed for {secret_name}: {str(e)}',
            Subject='ArgoCD Secret Rotation Failure'
        )
        raise e

def generate_new_gitlab_token(username):
    """Generate new GitLab personal access token"""
    # Implementation depends on GitLab API
    pass

def test_gitlab_token(token, url):
    """Test if GitLab token is valid"""
    headers = {'Private-Token': token}
    response = requests.get(f'{url}/api/v4/user', headers=headers)
    return response.status_code == 200

def trigger_argocd_refresh():
    """Trigger ArgoCD to refresh secrets"""
    # This could restart ArgoCD pods or call ArgoCD API
    pass