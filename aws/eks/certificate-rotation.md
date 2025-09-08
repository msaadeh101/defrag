# Rotating EKS Certificates

Cert-manager is a native K8 tool that automates the management and issuance of TLS certs. It automatically requests new certificates and stores them in K8.

0. Prerequisites:
- EKS Cluster with OIDC provider enabled (`aws eks describe-cluster`)
- AWS LB Controller deployed in EKS.
- Route 53 as your DNS for domain validation.
- cert-manager installed

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.12.0 \
  --create-namespace \
  --set installCRDs=true
```

- The above command installs cert-manager and its CRDs in the cert-manager namespace.

1. Create IAM Roles and Policies for cert-manager.

- The cert-manager pods need permission to modify Route 53 records to perform DNS-based challenges. Instead of access keys, use IRSA (IAM for Service Accounts).

- `cert-manager-route53-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/YOUR_HOSTED_ZONE_ID"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

- Create the policy using AWS cli:

```bash
aws iam create-policy \
  --policy-name CertManagerRoute53Policy \
  --policy-document file://cert-manager-route53-policy.json
```

- Create an IAM role with a Trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/oidc.eks.YOUR_AWS_REGION.amazonaws.com/id/EKS_OIDC_PROVIDER_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.YOUR_AWS_REGION.amazonaws.com/id/EKS_OIDC_PROVIDER_ID:sub": "system:serviceaccount:cert-manager:cert-manager"
        }
      }
    }
  ]
}
```

- Create the role:

```bash
aws iam create-role \
  --role-name cert-manager-route53-role \
  --assume-role-policy-document file://cert-manager-trust-policy.json
```

- Attach policy to the role:

```bash
aws iam attach-role-policy \
  --role-name cert-manager-route53-role \
  --policy-arn arn:aws:iam::YOUR_AWS_ACCOUNT_ID:policy/CertManagerRoute53Policy
```

2. Configure the cert-manager to use IRSA

- Annotate the cert-manager service account:

```bash
kubectl edit serviceaccount cert-manager -n cert-manager
```

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/cert-manager-route53-role"
```


3. Create **ClusterIssuer**: represents a certificate authority (CA) that will sign and issue your certificates. Use ClusterIssuer if you want to use the same CA across namespaces.
- For public facing apps, ACME (let's encrypt) is common

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - dns01:
        route53:
          region: us-east-1
          hostedZoneID: YOUR_HOSTED_ZONE_ID
          # Use an IAM role with permissions to modify Route 53 records
          # The service account for the cert-manager pod needs this role.
          accessKeyID: YOUR_AWS_ACCESS_KEY
          secretAccessKeySecretRef:
            name: aws-secret-key
            key: access-secret-key
```

4. Configure the Ingress Resource and **AWS Certificate Manager (ACM)**: Cert-manager can't provision a cert into ACM directly. We need a tool like acm-certificate-manager to automatically import a cert from K8 secret to ACM.

- Configure the Ingress Resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: my-app-namespace
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # Use the ARN of the certificate in ACM
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
spec:
  ingressClassName: alb
  rules:
  - host: myapp.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

This setup ensures that the AWS Load Balancer Controller uses the certificate from ACM.
