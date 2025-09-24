#!/bin/bash

BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_BUCKET="s3://company-argocd-backups"
REGION="us-west-2"

echo "🔄 Starting ArgoCD secrets backup..."

# Create backup directory
mkdir -p /tmp/argocd-backup-${BACKUP_DATE}

# Export Kubernetes secrets (encrypted)
kubectl get secrets -n argocd -o yaml > /tmp/argocd-backup-${BACKUP_DATE}/k8s-secrets.yaml

# Export External Secret configurations  
kubectl get externalsecrets -n argocd -o yaml > /tmp/argocd-backup-${BACKUP_DATE}/externalsecrets.yaml
kubectl get secretstores -n argocd -o yaml > /tmp/argocd-backup-${BACKUP_DATE}/secretstores.yaml

# Export ArgoCD configuration
kubectl get configmaps -n argocd -o yaml > /tmp/argocd-backup-${BACKUP_DATE}/configmaps.yaml

# Create AWS Secrets Manager backup references
aws secretsmanager list-secrets --region ${REGION} \
  --filters Key=name,Values=production/argocd \
  --query 'SecretList[*].{Name:Name,ARN:ARN}' \
  --output json > /tmp/argocd-backup-${BACKUP_DATE}/secrets-manager-refs.json

# Encrypt backup
tar -czf - /tmp/argocd-backup-${BACKUP_DATE} | \
  aws s3 cp - ${BACKUP_BUCKET}/argocd-secrets-${BACKUP_DATE}.tar.gz \
  --region ${REGION} \
  --sse aws:kms \
  --sse-kms-key-id alias/backup-encryption-key

# Cleanup
rm -rf /tmp/argocd-backup-${BACKUP_DATE}

echo "✅ Backup completed: ${BACKUP_BUCKET}/argocd-secrets-${BACKUP_DATE}.tar.gz"