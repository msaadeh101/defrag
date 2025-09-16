# EKS

## EKS and IRSA

1. `trust-policy.json`: Defines **who can assume the role**. for us, it is the specific SA s3-reader via OIDC. This file binds the IAM role to the `s3-reader` SA in the `default` namespace.
2. `permissions-policy.json`: Defines **what the role can do once assumed**, for us, it can read secrets from the secrets manager.

### How it Works Together

1. Create an IAM role using trust-policy.json as the assume_role_policy.
2. Attach permissions-policy.json to that rule using either:
    - aws_iam_role_policy (inline)
    - or aws_iam_role_policy_attachment (managed policy)
3. In Kubernetes, annotate the service account,  triggers IRSA to inject the IAM role into pod's identity via OIDC. `eks-irsa-s3-reader` is the name of the IAM role. defined when creating the role.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/eks-irsa-s3-reader
```