#!/bin/bash
# Generate SSH key for ArgoCD
ssh-keygen -t ed25519 -f argocd_gitlab_key -N ""

# Create GitLab deploy token via API
GITLAB_TOKEN=""  # Personal access token
PROJECT_ID=""

curl --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "argocd-deploy-token",
    "scopes": ["read_repository"],
    "expires_at": "2024-12-31"
  }' \
  "https://gitlab.example.com/api/v4/projects/${PROJECT_ID}/deploy_tokens"

# Configure repository in ArgoCD
argocd repo add https://gitlab.example.com/team/application.git \
  --username argocd-deploy-token \
  --password <deploy_token_value> \
  --tls-client-cert-file /path/to/cert.pem \
  --tls-client-cert-key-file /path/to/key.pem