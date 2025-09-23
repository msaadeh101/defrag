# ArgoCD AWS Complete Wiki

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Authentication & RBAC](#authentication--rbac)
6. [Application Management](#application-management)
7. [GitLab Integration](#gitlab-integration)
8. [Jenkins CI/CD Integration](#jenkins-cicd-integration)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Advanced Topics](#advanced-topics)

## Overview

**ArgoCD** is a declarative, GitOps continuous delivery tool for Kubernetes. Examples relate to Terraform/Helm/AWS.

### Key Benefits
- GitOps workflow with Git as single source of truth: Enables auditing and compliance.
- Declarative application management: Applications are defined ONCE in git, and ArgoCD continuously reconciles. Drift detection ensures EKS manifests match git manifests.
- Multi-cluster deployment support: Supports dev/stage/prod clusters across AWS accounts. (`argocd app set --dest-server=https://<prod-eks-api>`).
- Rich UI and CLI tools: Use `argocd` cli tool to script.
- Integration with AWS services

## Prerequisites

### AWS Resources Recommended
- EKS cluster (1.27+)
- VPC with private/public subnets
- ALB Ingress Controller (Layer 7 routing and TLS termination)
- External DNS (optional)
- ACM certificates for HTTPS
- Route53 hosted zone for DNS automation.

### Tools Required
```bash
# Required CLI tools
aws --version       # >= 2.0
kubectl version     # >= 1.27
helm version        # >= 3.12
terraform version   # >= 1.6
argocd version      # >= 2.9
```

- Optional tools: kustomize (for overlays per env), sops (for encrypted secrets), jq (for automation and scripting)

### Quickstart Worflow
1. Infra with Terraform:
- Provision EKS, ALB, IAM Roles, Policies, Secrets Manager
2. App Manifests with Helm:
- Charts for Java services (`charts/java-orders-service/`)
- Values overridden per env with overlays (`overlays/dev/values.yaml`)
3. ArgoCD Application Definition:
- GitOps manifest references Helm Chart + Values
- K8 manifest: `apiVersion: argoproj.io/v1alpha1`, `repoURL`, `path`, `targetRevision`, `helm` etc.
4. Continuous Delivery:
- Commit an updated tag -> ArgoCD detects change -> Deploys new version.
- Argo Rollouts for Canary/Blue-Green Deployments.

## Installation

### 1. EKS Cluster Setup with Terraform

```hcl
# eks-cluster.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_config = {
    private_access = true
    public_access  = true
    public_access_cidrs = ["0.0.0.0/0"]
  }
  
  # Ensure argocd runs on isolated nodes.
  eks_managed_node_groups = {
    argocd_nodes = {
      name = "argocd-nodes"
      
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 5
      desired_size   = 3

      k8s_labels = {
        Environment = var.environment
        Application = "argocd"
      }
      # No pod will be scheduled onto the node unless there is a matching toleration
      taints = {
        dedicated = {
          key    = "argocd"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      } # Only pods with key=argocd, value=true, and effect=NoSchedule will be running on the node
    }
  }

  # Enable IRSA
  enable_irsa = true

  tags = var.common_tags
}

# ALB Controller IAM Role
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

- Only pods with the below matching toleration can be placed in the argocd nodes:
```yaml
tolerations:
- key: "argocd"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

### 2. ArgoCD IRSA Setup

```hcl
# argocd-irsa.tf
data "aws_iam_policy_document" "argocd_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:argocd/*",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/argocd/*"
    ]
  }
}

resource "aws_iam_policy" "argocd_policy" {
  name        = "${var.cluster_name}-argocd-policy"
  description = "ArgoCD service account policy"
  policy      = data.aws_iam_policy_document.argocd_policy.json
}

module "argocd_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-argocd"

  role_policy_arns = {
    policy = aws_iam_policy.argocd_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd-server", "argocd:argocd-application-controller"]
    }
  }
}
```

### 3. ArgoCD Helm Installation

- Pull in your Kube Config:
```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name CLUSTER_NAME
```

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd
```

- Helm values.yaml override file when using the official helm chart
```yaml
# argocd-values.yaml
global:
  domain: argocd.example.com # Must match the Route53 record and ACM TLS certificate

configs:
  params:
    server.insecure: false # Forces HTTPS (TLS included)
    server.rootpath: /
  cm:                                # Congures the ArgoCD Configmap
    url: https://argocd.example.com
    dex.config: | # Dex is the built in argocd OIDC provider
      connectors:
        - type: oidc
          id: aws-sso
          name: AWS SSO
          config:
            issuer: https://portal.sso.us-west-2.amazonaws.com
            clientId: $oidc.aws.clientId        # Pulled from K8 secrets
            clientSecret: $oidc.aws.clientSecret
            requestedScopes: ["openid", "profile", "email"]
            requestedIDTokenClaims: {"groups": {"essential": true}}

server:
  serviceAccount: # Creates a dedicated service account for the ArgoCD server
    create: true
    annotations: # IRSA role to touch AWS resources
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/CLUSTER_NAME-argocd"
  
  ingress:               # Configures ingress view AWS ALB Ingress controller
    enabled: true        # TLS termination with ACM certificate
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/ssl-redirect: '443'
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-west-2:ACCOUNT_ID:certificate/CERT_ID" 
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      external-dns.alpha.kubernetes.io/hostname: argocd.example.com   # Auto DNS records management via External DNS
    hosts:
      - host: argocd.example.com
        paths: # Routes all traffic at / to ArgoCD server
          - path: /
            pathType: Prefix
    tls:
      - secretName: argocd-server-tls
        hosts:
          - argocd.example.com

controller:        # ArgoCD app controller gets its own Service Account with IRSA role
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/CLUSTER_NAME-argocd"
  
  nodeSelector:
    kubernetes.io/os: linux
  
  tolerations:
    - key: "argocd"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

repoServer:        # Responsible for rendering manifests (Helm/Kustomize)
  nodeSelector:
    kubernetes.io/os: linux
  
  tolerations:
    - key: "argocd"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

redis:                 # ArgoCD uses Redis for caching app state and improving performance
  enabled: true
  nodeSelector:
    kubernetes.io/os: linux

dex:                  # Enables Dex identity service, must be enabled for OIDC integration with AWS SSO
  enabled: true
  nodeSelector:
    kubernetes.io/os: linux

applicationSet:     # Used dynamicallly to create new apps. Deploys the same microservice using a single template
  enabled: true
```

```bash
# Install ArgoCD, must already be authenticated to cluster
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd-values.yaml \
  --version 5.46.8
```

## Configuration

### 1. Repository Credentials

```yaml
# git-repo-secret.yaml/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: private-repo
  namespace: argocd
spec:
  secretStoreRef:
    name: aws-secrets
    kind: ClusterSecretStore
  target:
    name: private-repo
  data:
    - secretKey: password
      remoteRef:
        key: /gitlab/pat
        property: token
    - secretKey: username
      remoteRef:
        key: /gitlab/pat
        property: username
  template:
    type: Opaque
    metadata:
      labels:
        argocd.argoproj.io/secret-type: repository
    data:
      type: git
      url: https://gitlab.com/company/k8s-manifests
```

### 2. Cluster Registration

```bash
# Add external cluster
argocd cluster add arn:aws:eks:us-west-2:123456789012:cluster/production \
  --name production \
  --server https://argocd.example.com
```

### 3. Multi-Region Setup

```yaml
# cluster-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: production-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: production
  server: https://<EKS_CLUSTER_ENDPOINT>  # dynamically discovered via `aws eks describe-cluster`
  config: |
    {
      "execProvider": {
        "command": "aws",
        "args": ["eks", "get-token", "--cluster-name", "production", "--region", "us-west-2"],
        "apiVersion": "client.authentication.k8s.io/v1beta1"
      },
      "tlsClientConfig": {
        "insecure": false
      }
    }
```
- `aws eks get-token` + **default kube config** covers embedding the Cert Authority data.

## Authentication & RBAC

### 1. AWS SSO Integration
- First store OIDC Secret in AWS Secretes Manager

```bash
aws secretsmanager create-secret \
  --name argocd-aws-sso-oidc \
  --description "OIDC client credentials for ArgoCD AWS SSO" \
  --secret-string '{"clientId":"12345","clientSecret":"some-value"}'
```

- Install external secrets operator:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

- Create the External secret:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-oidc
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: ClusterSecretStore
  target:
    name: argocd-oidc-secret
    creationPolicy: Owner
  data:
    - secretKey: oidc.aws.clientId
      remoteRef:
        key: argocd-aws-sso-oidc
        property: clientId
    - secretKey: oidc.aws.clientSecret
      remoteRef:
        key: argocd-aws-sso-oidc
        property: clientSecret
```

- ArgoCD Patch ConfigMap:
```yaml
# configmap patch for AWS SSO
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  oidc.config: |
    name: AWS SSO
    issuer: https://portal.sso.us-west-2.amazonaws.com
    clientID: $oidc.aws.clientId
    clientSecret: $oidc.aws.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims: {"groups": {"essential": true}}

  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, applications, sync, */*, deny
    g, argocd-admins, role:admin
    g, argocd-developers, role:readonly
```

- IAM Permissions (IRSA)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:123456789012:secret:argocd-aws-sso-oidc*"
    }
  ]
}
```

### 2. AppProject RBAC

```yaml
# app-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production          # Name of the project
  namespace: argocd
spec:
  description: Production applications
  
  # Allowed git repos, trusted helm chart repos
  sourceRepos:
    - 'https://gitlab.com/company/k8s-manifests'
    - 'https://charts.example.com'
  
  # Allowed destinations, any namespace on the Kubernetes API
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
      name: production-cluster
  
  clusterResourceWhitelist: # Prevents apps from creating dangerous cluster-wide resources
    - group: ''
      kind: Namespace
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
    - group: rbac.authorization.k8s.io
      kind: ClusterRoleBinding
  
  namespaceResourceWhitelist: # Allows more flexibility within the namespace
    - group: ''
      kind: '*'
    - group: apps
      kind: '*'
    - group: extensions
      kind: '*'
  
  roles:
    - name: production-admin
      description: Admin access to production
      policies:
        # Policy: (p) subject=proj:production:production-admin
        # Can perform *any* action (*) on *all* applications under project "production"
        - p, proj:production:production-admin, applications, *, production/*, allow
      groups:
        - argocd-production-admins
    # Any SSO user/group (mapped from AWS SSO OIDC groups) in this ArgoCD RBAC group
    # will be bound to "production-admin" role, granting them the above policy

```

## Application Management

### 1. Basic Application

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io # Cleans up app managed resources if app is deleted
spec:
  project: default # The project defines gaurdrails like repos, destinations, RBAC
  
  source:
    repoURL: https://gitlab.com/company/k8s-manifests
    targetRevision: main
    path: apps/nginx
    
  destination:
    server: https://kubernetes.default.svc    # This is the in-cluster API server
    namespace: nginx
  
  # Define the sync behavior
  syncPolicy:
    automated:
      prune: true      # Automatically delete resources not found in git
      selfHeal: true    # Automatically revert live drift
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground    # Wait for dependent resources to be deleted
      - PruneLast=true                       # Prune deletions happen after all syncs for create/updates
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2               # Exponential backoff
        maxDuration: 3m
```

### 2. Helm Application

- This example pulls from the Prometheus public helm chart
```yaml
# helm-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: monitoring
  
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 52.1.0
    helm:
      releaseName: prometheus
      values: |   # Override the default values
        prometheus:
          prometheusSpec:
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: gp3
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 100Gi
        grafana:
          persistence:
            enabled: true
            storageClassName: gp3
            size: 10Gi
  
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3. ApplicationSet for Multi-Environment

- An ApplicationSet is a template + generator: You write one and it expands to many Application resources automatically:
```yaml
# applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd    # The ApplicationSet lives in the argocd namesapce
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  - git:
      repoURL: https://github.com/company/k8s-manifests
      revision: HEAD
      directories:
      - path: apps/*
  
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/company/k8s-manifests
        targetRevision: HEAD
        path: '{{path}}'
        helm:
          values: |
            environment: '{{metadata.labels.environment}}'
            cluster: '{{name}}'
      destination:
        server: '{{server}}'
        namespace: '{{path.basename}}'    # Namespace to deploy the app to
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

### 4. Kustomize Application

```yaml
# kustomize-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/company/k8s-manifests
    targetRevision: main
    path: overlays/production
    kustomize:
      images:
        - name: webapp
          newTag: v2.1.0
      patchesStrategicMerge:
        - |-
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: webapp
          spec:
            template:
              metadata:
                annotations:
                  cluster: production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp
```

## GitLab Integration

### 1. GitLab Repository Configuration

#### Repository Credentials Setup
```yaml
# external-secrets-setup.yaml
# First, install External Secrets Operator
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: external-secrets-system
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/CLUSTER_NAME-external-secrets"

---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-store
  namespace: argocd
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
# GitLab Git Repository Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gitlab-repo-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-store
    kind: SecretStore
  target:
    name: gitlab-repo
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: repository
      data:
        type: git
        url: https://gitlab.company.com/k8s/manifests.git
        username: argocd-service-account
        password: "{{ .gitlabToken }}"
        sshPrivateKey: "{{ .gitlabSshKey }}"
  data:
  - secretKey: gitlabToken
    remoteRef:
      key: argocd/gitlab/token
  - secretKey: gitlabSshKey
    remoteRef:
      key: argocd/gitlab/ssh-key

---
# GitLab Helm Repository Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gitlab-helm-repo-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-store
    kind: SecretStore
  target:
    name: gitlab-helm-repo
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: repository
      data:
        type: helm
        url: https://gitlab.company.com/api/v4/projects/123/packages/helm/stable
        username: argocd-service-account
        password: "{{ .gitlabHelmToken }}"
  data:
  - secretKey: gitlabHelmToken
    remoteRef:
      key: argocd/gitlab/helm-token
```

#### GitLab CI/CD Integration
```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy-manifest
  - notify-argocd

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  KUBECONFIG: /tmp/kubeconfig
  ARGOCD_SERVER: "argocd.company.com"

before_script:
  - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY

build:
  stage: build
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
    - develop

update-manifests:
  stage: deploy-manifest
  image: alpine/git:latest
  before_script:
    - apk add --no-cache yq
    - git config --global user.email "argocd@company.com"
    - git config --global user.name "ArgoCD GitLab CI"
  script:
    - git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.company.com/k8s/manifests.git
    - cd manifests
    - |
      if [ "$CI_COMMIT_REF_NAME" = "main" ]; then
        ENV_PATH="overlays/production"
      else
        ENV_PATH="overlays/staging"
      fi
    - yq e ".images[0].newTag = \"$CI_COMMIT_SHA\"" -i $ENV_PATH/kustomization.yaml
    - git add $ENV_PATH/kustomization.yaml
    - git commit -m "Update image tag to $CI_COMMIT_SHA for $CI_COMMIT_REF_NAME"
    - git push origin main
  only:
    - main
    - develop

trigger-argocd-sync:
  stage: notify-argocd
  image: curlimages/curl:latest
  script:
    - |
      if [ "$CI_COMMIT_REF_NAME" = "main" ]; then
        APP_NAME="webapp-production"
      else
        APP_NAME="webapp-staging"
      fi
    - |
      curl -X POST \
        -H "Authorization: Bearer $ARGOCD_TOKEN" \
        -H "Content-Type: application/json" \
        https://$ARGOCD_SERVER/api/v1/applications/$APP_NAME/sync \
        -d '{"prune": true, "dryRun": false}'
  only:
    - main
    - develop
```

### 2. GitLab Webhooks Configuration

#### ArgoCD Webhook Receiver
```yaml
# gitlab-webhook-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.webhook.gitlab: |
    url: https://gitlab.company.com/api/v4
    headers:
    - name: Private-Token
      value: $gitlab-token
    - name: Content-Type
      value: application/json

  template.gitlab-commit-status: |
    webhook:
      gitlab:
        method: POST
        path: /projects/{{.app.spec.source.repoURL | call .repo.RepoURLToProjectID}}/statuses/{{.app.status.sync.revision}}
        body: |
          {
            "state": "{{if eq .app.status.health.status "Healthy"}}success{{else}}failed{{end}}",
            "target_url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "description": "ArgoCD deployment {{.app.status.health.status}}",
            "name": "argocd/{{.app.metadata.name}}"
          }

  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      send: [gitlab-commit-status]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [gitlab-commit-status]
```

### 3. GitLab Authentication Integration

```yaml
# gitlab-dex-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  dex.config: |
    connectors:
    - type: gitlab
      id: gitlab
      name: GitLab
      config:
        baseURL: https://gitlab.company.com
        clientID: $dex.gitlab.clientId
        clientSecret: $dex.gitlab.clientSecret
        redirectURI: https://argocd.company.com/api/dex/callback
        groups:
        - argocd-admins
        - argocd-developers
        useLoginAsID: false

  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, action/*, */*, allow
    g, argocd-admins, role:admin
    g, argocd-developers, role:developer
```

### 4. Multi-Project GitLab Setup

```yaml
# gitlab-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: gitlab-projects
  namespace: argocd
spec:
  generators:
  - scmProvider:
      gitlab:
        group: k8s
        api: https://gitlab.company.com/api/v4
        tokenRef:
          secretName: gitlab-token
          key: token
        allBranches: false
        
  template:
    metadata:
      name: '{{repository}}-{{branch}}'
      annotations:
        argocd.argoproj.io/tracking-id: '{{repository}}:{{path}}'
    spec:
      project: default
      source:
        repoURL: '{{url}}'
        targetRevision: '{{branch}}'
        path: k8s
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{repository}}-{{branch}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Jenkins CI/CD Integration

### 1. Jenkins Setup on EKS

#### Jenkins Helm Installation
```yaml
# jenkins-values.yaml
controller:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/CLUSTER_NAME-jenkins"
  
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-west-2:ACCOUNT_ID:certificate/CERT_ID"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      external-dns.alpha.kubernetes.io/hostname: jenkins.company.com
    hostName: jenkins.company.com

  persistence:
    enabled: true
    storageClass: gp3
    size: 100Gi

  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

  installPlugins:
    - kubernetes:latest
    - workflow-multibranch:latest
    - git:latest
    - configuration-as-code:latest
    - blueocean:latest
    - pipeline-stage-view:latest
    - docker-workflow:latest
    - kubernetes-credentials-provider:latest

  JCasC:
    defaultConfig: true
    configScripts:
      argocd-config: |
        jenkins:
          securityRealm:
            local:
              allowsSignup: false
              users:
                - id: admin
                  password: ${ADMIN_PASSWORD}
        
        credentials:
          system:
            domainCredentials:
            - credentials:
              - string:
                  scope: GLOBAL
                  id: argocd-token
                  secret: ${ARGOCD_TOKEN}
              - usernamePassword:
                  scope: GLOBAL
                  id: gitlab-credentials
                  username: jenkins
                  password: ${GITLAB_TOKEN}
              - string:
                  scope: GLOBAL
                  id: docker-registry-token
                  secret: ${DOCKER_REGISTRY_TOKEN}

agent:
  enabled: true
  image: jenkins/inbound-agent
  tag: latest
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"
```

```bash
# Install Jenkins
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins -n jenkins --create-namespace -f jenkins-values.yaml
```

### 2. Jenkins Pipeline Integration

#### Jenkinsfile for ArgoCD Integration
```groovy
// Jenkinsfile
pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: docker
                    image: docker:20.10.16-dind
                    privileged: true
                    env:
                    - name: DOCKER_TLS_CERTDIR
                      value: ""
                  - name: kubectl
                    image: bitnami/kubectl:latest
                    command:
                    - sleep
                    args:
                    - 99d
                  - name: argocd
                    image: argoproj/argocd:v2.8.4
                    command:
                    - sleep
                    args:
                    - 99d
            '''
        }
    }
    
    environment {
        DOCKER_REGISTRY = "123456789012.dkr.ecr.us-west-2.amazonaws.com"
        IMAGE_NAME = "webapp"
        ARGOCD_SERVER = "argocd.company.com"
        GIT_MANIFEST_REPO = "https://gitlab.company.com/k8s/manifests.git"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "echo ${env.GIT_COMMIT} | cut -c1-8",
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        stage('Build & Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                            echo "Running unit tests..."
                            # Add your test commands here
                        '''
                    }
                }
                
                stage('Build Docker Image') {
                    steps {
                        container('docker') {
                            script {
                                sh '''
                                    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $DOCKER_REGISTRY
                                    docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
                                    docker tag $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG $DOCKER_REGISTRY/$IMAGE_NAME:latest
                                    docker push $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
                                    docker push $DOCKER_REGISTRY/$IMAGE_NAME:latest
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                container('docker') {
                    sh '''
                        echo "Running security scan..."
                        # Trivy scan
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                          aquasec/trivy image --exit-code 1 --severity HIGH,CRITICAL \
                          $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }
        
        stage('Update Manifests') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    def environment = (env.BRANCH_NAME == 'main') ? 'production' : 'staging'
                    
                    withCredentials([usernamePassword(credentialsId: 'gitlab-credentials', 
                                                    usernameVariable: 'GIT_USERNAME', 
                                                    passwordVariable: 'GIT_PASSWORD')]) {
                        sh """
                            git clone https://\$GIT_USERNAME:\$GIT_PASSWORD@gitlab.company.com/k8s/manifests.git
                            cd manifests
                            
                            # Update kustomization.yaml
                            sed -i 's|newTag:.*|newTag: ${IMAGE_TAG}|' overlays/${environment}/kustomization.yaml
                            
                            # Commit and push changes
                            git config user.email "jenkins@company.com"
                            git config user.name "Jenkins CI"
                            git add overlays/${environment}/kustomization.yaml
                            git commit -m "Update ${IMAGE_NAME} image tag to ${IMAGE_TAG} for ${environment}"
                            git push origin main
                        """
                    }
                }
            }
        }
        
        stage('Deploy to ArgoCD') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                container('argocd') {
                    script {
                        def appName = (env.BRANCH_NAME == 'main') ? 'webapp-production' : 'webapp-staging'
                        
                        withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_AUTH_TOKEN')]) {
                            sh """
                                argocd login $ARGOCD_SERVER --username admin --password \$ARGOCD_AUTH_TOKEN --insecure
                                
                                # Refresh the app to detect changes
                                argocd app get ${appName} --refresh
                                
                                # Sync the application
                                argocd app sync ${appName} --prune
                                
                                # Wait for sync to complete
                                argocd app wait ${appName} --timeout 600
                                
                                # Check health status
                                argocd app get ${appName}
                            """
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                def appName = (env.BRANCH_NAME == 'main') ? 'webapp-production' : 'webapp-staging'
                slackSend(
                    color: 'good',
                    message: "✅ Successfully deployed ${IMAGE_NAME}:${IMAGE_TAG} to ${appName}"
                )
            }
        }
        failure {
            slackSend(
                color: 'danger',
                message: "❌ Failed to deploy ${IMAGE_NAME}:${IMAGE_TAG}"
            )
        }
    }
}
```

### 3. Jenkins Shared Library for ArgoCD

```groovy
// vars/deployToArgoCD.groovy
def call(Map config) {
    def appName = config.appName
    def imageTag = config.imageTag
    def environment = config.environment
    def timeout = config.timeout ?: 600
    
    container('argocd') {
        withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_TOKEN')]) {
            sh """
                argocd login ${env.ARGOCD_SERVER} --username admin --password \$ARGOCD_TOKEN --insecure
                
                # Set image tag parameter
                argocd app set ${appName} --parameter image.tag=${imageTag}
                
                # Sync application
                argocd app sync ${appName} --prune --strategy replace
                
                # Wait for deployment
                argocd app wait ${appName} --timeout ${timeout} --health
                
                # Get final status
                argocd app get ${appName} --output json | jq '.status.health.status'
            """
        }
    }
}

// Usage in Jenkinsfile:
// deployToArgoCD([
//     appName: 'webapp-production',
//     imageTag: env.IMAGE_TAG,
//     environment: 'production'
// ])
```

### 4. ArgoCD Jenkins Plugin Configuration

```groovy
// jenkins-argocd-plugin.groovy
pipeline {
    agent any
    
    stages {
        stage('Deploy with ArgoCD Plugin') {
            steps {
                script {
                    argocdDeploy(
                        server: 'argocd.company.com',
                        application: 'webapp-production',
                        revision: env.GIT_COMMIT,
                        sync: true,
                        prune: true,
                        timeout: 600,
                        credentialsId: 'argocd-token'
                    )
                }
            }
        }
    }
}
```

### 5. Multi-Branch Pipeline with ArgoCD

```groovy
// Multi-branch Jenkinsfile
pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: tools
                    image: argoproj/argocd:v2.8.4
                    command: [sleep]
                    args: [99d]
            '''
        }
    }
    
    environment {
        ARGOCD_SERVER = "argocd.company.com"
    }
    
    stages {
        stage('Deploy Feature Branch') {
            when {
                not {
                    anyOf {
                        branch 'main'
                        branch 'develop'
                    }
                }
            }
            steps {
                container('tools') {
                    script {
                        def branchName = env.BRANCH_NAME.replaceAll(/[^a-zA-Z0-9]/, '-').toLowerCase()
                        def appName = "webapp-feature-${branchName}"
                        
                        withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_TOKEN')]) {
                            sh """
                                argocd login $ARGOCD_SERVER --username admin --password \$ARGOCD_TOKEN --insecure
                                
                                # Create temporary application for feature branch
                                cat <<EOF | argocd app create -f -
                                apiVersion: argoproj.io/v1alpha1
                                kind: Application
                                metadata:
                                  name: ${appName}
                                  namespace: argocd
                                spec:
                                  project: default
                                  source:
                                    repoURL: ${GIT_MANIFEST_REPO}
                                    targetRevision: HEAD
                                    path: overlays/feature
                                    helm:
                                      parameters:
                                      - name: image.tag
                                        value: ${env.BUILD_NUMBER}
                                      - name: namespace
                                        value: ${appName}
                                  destination:
                                    server: https://kubernetes.default.svc
                                    namespace: ${appName}
                                  syncPolicy:
                                    automated:
                                      prune: true
                                      selfHeal: true
                                    syncOptions:
                                    - CreateNamespace=true
                                EOF
                                
                                # Sync the application
                                argocd app sync ${appName}
                                argocd app wait ${appName} --timeout 300
                            """
                        }
                    }
                }
            }
        }
        
        stage('Cleanup Feature Branch') {
            when {
                allOf {
                    not { anyOf { branch 'main'; branch 'develop' } }
                    triggeredBy 'BranchEventCause'
                    equals expected: 'DELETED', actual: env.CHANGE_TYPE
                }
            }
            steps {
                container('tools') {
                    script {
                        def branchName = env.BRANCH_NAME.replaceAll(/[^a-zA-Z0-9]/, '-').toLowerCase()
                        def appName = "webapp-feature-${branchName}"
                        
                        withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_TOKEN')]) {
                            sh """
                                argocd login $ARGOCD_SERVER --username admin --password \$ARGOCD_TOKEN --insecure
                                argocd app delete ${appName} --cascade --yes || true
                                kubectl delete namespace ${appName} --ignore-not-found=true
                            """
                        }
                    }
                }
            }
        }
    }
}
```

### 1. Resource Management

```yaml
# argocd resource limits
server:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

controller:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

repoServer:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
```

### 2. Security Configuration

```yaml
# security hardening
configs:
  params:
    server.insecure: false
    server.grpc.web: true
    controller.operation.processors: 20
    controller.status.processors: 20
    controller.self.heal.timeout.seconds: 5
    controller.repo.server.timeout.seconds: 60
  cm:
    accounts.admin: apiKey,login
    accounts.ci: apiKey
    exec.enabled: false
    admin.enabled: false
    timeout.reconciliation: 180s
```

### 3. Monitoring Integration

```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### 4. Backup Strategy

```bash
#!/bin/bash
# argocd-backup.sh
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/argocd/${BACKUP_DATE}"
S3_BUCKET="s3://company-argocd-backups"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Export ArgoCD resources
kubectl get applications -n argocd -o yaml > ${BACKUP_DIR}/applications.yaml
kubectl get appprojects -n argocd -o yaml > ${BACKUP_DIR}/appprojects.yaml
kubectl get configmaps -n argocd -o yaml > ${BACKUP_DIR}/configmaps.yaml
kubectl get secrets -n argocd -o yaml > ${BACKUP_DIR}/secrets.yaml

# Upload to S3
aws s3 sync ${BACKUP_DIR} ${S3_BUCKET}/${BACKUP_DATE}/

# Cleanup local backup (keep last 7 days)
find /backup/argocd -type d -mtime +7 -exec rm -rf {} +
```

## Troubleshooting

### 1. Common Issues

```bash
# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check sync status
argocd app get myapp --show-operation

# Force refresh repository
argocd app get myapp --refresh

# Hard refresh (bypass cache)
argocd app get myapp --hard-refresh
```

### 2. Performance Tuning

```yaml
# controller tuning for large clusters
controller:
  env:
    - name: ARGOCD_CONTROLLER_REPLICAS
      value: "1"
    - name: ARGOCD_CONTROLLER_OPERATION_PROCESSORS
      value: "20"
    - name: ARGOCD_CONTROLLER_STATUS_PROCESSORS
      value: "20"
    - name: ARGOCD_CONTROLLER_SELF_HEAL_TIMEOUT_SECONDS
      value: "5"
    - name: ARGOCD_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS
      value: "60"
```

### 3. Debug Commands

```bash
# Enable debug logging
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  --patch '{"data":{"controller.log.level":"debug","server.log.level":"debug"}}'

# Check resource usage
kubectl top pods -n argocd

# Validate application manifests
argocd app manifests myapp --local /path/to/manifests

# Diff between git and cluster
argocd app diff myapp
```

## Advanced Topics

### 1. Multi-Cluster Management

```yaml
# cluster-generator.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
      values:
        nodeSize: large
        monitoring: enabled
  
  template:
    metadata:
      name: '{{name}}-addons'
    spec:
      project: cluster-addons
      source:
        repoURL: https://github.com/company/cluster-addons
        targetRevision: HEAD
        path: overlays/{{metadata.labels.environment}}
        helm:
          values: |
            cluster:
              name: '{{name}}'
              region: '{{metadata.labels.region}}'
              nodeSize: '{{values.nodeSize}}'
              monitoring: '{{values.monitoring}}'
      destination:
        server: '{{server}}'
        namespace: kube-system
```

### 2. Custom Health Checks

```yaml
# custom-health.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.argoproj.io_Rollout: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.replicas ~= nil and obj.status.updatedReplicas ~= nil and obj.status.readyReplicas ~= nil and obj.status.availableReplicas ~= nil then
        if obj.status.replicas == obj.status.updatedReplicas and obj.status.replicas == obj.status.readyReplicas and obj.status.replicas == obj.status.availableReplicas then
          hs.status = "Healthy"
          hs.message = "Rollout is healthy"
          return hs
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Rollout is progressing"
    return hs
```

### 3. Webhooks Integration

```yaml
# webhook-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.webhook.github: |
    url: https://api.github.com
    headers:
    - name: Authorization
      value: token $github-token
  
  template.app-deployed: |
    webhook:
      github:
        method: POST
        path: /repos/{{.app.spec.source.repoURL | call .repo.RepoURLToHTTPS | call .repo.FullNameByRepoURL}}/statuses/{{.app.status.operationState.operation.sync.revision}}
        body: |
          {
            "state": "success",
            "target_url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "description": "ArgoCD",
            "context": "continuous-delivery/{{.app.metadata.name}}"
          }
```

### 4. Progressive Delivery with Argo Rollouts

```yaml
# rollout-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-rollout
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/company/k8s-manifests
    targetRevision: HEAD
    path: rollouts/webapp
  
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Disable for rollouts
    syncOptions:
      - CreateNamespace=true
```

```yaml
# rollout manifest example
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: webapp
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: webapp-canary
      stableService: webapp-stable
      trafficRouting:
        alb:
          ingress: webapp-ingress
          servicePort: 80
          rootService: webapp-stable
      steps:
      - setWeight: 10
      - pause:
          duration: 5m
      - setWeight: 25
      - pause:
          duration: 10m
      - setWeight: 50
      - pause:
          duration: 15m
```

## Best Practices

### 1. Resource Management

```yaml
# argocd resource limits
server:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

controller:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

repoServer:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
```

### 2. Security Configuration

```yaml
# security hardening
configs:
  params:
    server.insecure: false
    server.grpc.web: true
    controller.operation.processors: 20
    controller.status.processors: 20
    controller.self.heal.timeout.seconds: 5
    controller.repo.server.timeout.seconds: 60
  cm:
    accounts.admin: apiKey,login
    accounts.ci: apiKey
    exec.enabled: false
    admin.enabled: false
    timeout.reconciliation: 180s
```

### 3. Monitoring Integration

```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### 4. Backup Strategy

```bash
#!/bin/bash
# argocd-backup.sh
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/argocd/${BACKUP_DATE}"
S3_BUCKET="s3://company-argocd-backups"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Export ArgoCD resources
kubectl get applications -n argocd -o yaml > ${BACKUP_DIR}/applications.yaml
kubectl get appprojects -n argocd -o yaml > ${BACKUP_DIR}/appprojects.yaml
kubectl get configmaps -n argocd -o yaml > ${BACKUP_DIR}/configmaps.yaml
kubectl get secrets -n argocd -o yaml > ${BACKUP_DIR}/secrets.yaml

# Upload to S3
aws s3 sync ${BACKUP_DIR} ${S3_BUCKET}/${BACKUP_DATE}/

# Cleanup local backup (keep last 7 days)
find /backup/argocd -type d -mtime +7 -exec rm -rf {} +
```

## Troubleshooting

### 1. Common Issues

```bash
# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check sync status
argocd app get myapp --show-operation

# Force refresh repository
argocd app get myapp --refresh

# Hard refresh (bypass cache)
argocd app get myapp --hard-refresh
```

### 2. Performance Tuning

```yaml
# controller tuning for large clusters
controller:
  env:
    - name: ARGOCD_CONTROLLER_REPLICAS
      value: "1"
    - name: ARGOCD_CONTROLLER_OPERATION_PROCESSORS
      value: "20"
    - name: ARGOCD_CONTROLLER_STATUS_PROCESSORS
      value: "20"
    - name: ARGOCD_CONTROLLER_SELF_HEAL_TIMEOUT_SECONDS
      value: "5"
    - name: ARGOCD_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS
      value: "60"
```

### 3. Debug Commands

```bash
# Enable debug logging
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  --patch '{"data":{"controller.log.level":"debug","server.log.level":"debug"}}'

# Check resource usage
kubectl top pods -n argocd

# Validate application manifests
argocd app manifests myapp --local /path/to/manifests

# Diff between git and cluster
argocd app diff myapp
```

## Advanced Topics

### 1. Multi-Cluster Management

```yaml
# cluster-generator.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
      values:
        nodeSize: large
        monitoring: enabled
  
  template:
    metadata:
      name: '{{name}}-addons'
    spec:
      project: cluster-addons
      source:
        repoURL: https://github.com/company/cluster-addons
        targetRevision: HEAD
        path: overlays/{{metadata.labels.environment}}
        helm:
          values: |
            cluster:
              name: '{{name}}'
              region: '{{metadata.labels.region}}'
              nodeSize: '{{values.nodeSize}}'
              monitoring: '{{values.monitoring}}'
      destination:
        server: '{{server}}'
        namespace: kube-system
```

### 2. Custom Health Checks

```yaml
# custom-health.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.argoproj.io_Rollout: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.replicas ~= nil and obj.status.updatedReplicas ~= nil and obj.status.readyReplicas ~= nil and obj.status.availableReplicas ~= nil then
        if obj.status.replicas == obj.status.updatedReplicas and obj.status.replicas == obj.status.readyReplicas and obj.status.replicas == obj.status.availableReplicas then
          hs.status = "Healthy"
          hs.message = "Rollout is healthy"
          return hs
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Rollout is progressing"
    return hs
```

### 3. Webhooks Integration

```yaml
# webhook-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.webhook.github: |
    url: https://api.github.com
    headers:
    - name: Authorization
      value: token $github-token
  
  template.app-deployed: |
    webhook:
      github:
        method: POST
        path: /repos/{{.app.spec.source.repoURL | call .repo.RepoURLToHTTPS | call .repo.FullNameByRepoURL}}/statuses/{{.app.status.operationState.operation.sync.revision}}
        body: |
          {
            "state": "success",
            "target_url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "description": "ArgoCD",
            "context": "continuous-delivery/{{.app.metadata.name}}"
          }
```

### 4. Progressive Delivery with Argo Rollouts

```yaml
# rollout-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-rollout
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/company/k8s-manifests
    targetRevision: HEAD
    path: rollouts/webapp
  
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Disable for rollouts
    syncOptions:
      - CreateNamespace=true
```

```yaml
# rollout manifest example
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: webapp
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: webapp-canary
      stableService: webapp-stable
      trafficRouting:
        alb:
          ingress: webapp-ingress
          servicePort: 80
          rootService: webapp-stable
      steps:
      - setWeight: 10
      - pause:
          duration: 5m
      - setWeight: 25
      - pause:
          duration: 10m
      - setWeight: 50
      - pause:
          duration: 15m
```

This wiki provides comprehensive coverage of ArgoCD deployment and management on AWS. Each section includes practical examples and follows AWS best practices for production deployments.