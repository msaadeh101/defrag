# AWS IAM

## Core IAM Concepts

- Identity-Based Policies: Attached to IAM users, groups or roles. Define what actions an identity can perform.
- Resource-Based Policies: Attached to resources like S3 buckets and KMS Keys. Define who can access the resource.

Policy Evaluation Logic:
1. Explicit DENY: Always wins.
2. Explicit ALLOW: Required for access.
3. Implicit DENY: Default when no allow exists.

Principal Types:
- AWS Account: `arn:aws:iam::123456789012:root`
- IAM User: `arn:aws:iam::123456789012:user/UserName`
- IAM Role: `arn:aws:iam::123456789012:role/RoleName`
- Federated User: `arn:aws:sts::123456789012:federated-user/UserName`
- Service: `ec2.amazonaws.com`

## IAM Policies

### Policy Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UniqueStatementId",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/Alice"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

### Policy Types

1. AWS Managed Policies: Predefined by AWS, CANNOT be modified.

```bash
# List AWS Managed policies
aws iam list-policies --scope AWS --max-items 10

# Examples:
# - PowerUserAccess
# - ReadOnlyAccess
# - SecurityAudit
```

2. Customer Managed Policies: Created and Managed by user.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Environment": "dev"
        }
      }
    }
  ]
}
```

3. Inline Policies: Embedded directly in a user, group or role. Deleted when identity is deleted.

```bash
# Create inline policy for DevUser
aws iam put-user-policy \
  --user-name DevUser \
  --policy-name S3ReadOnly \
  --policy-document file://policy.json
```

### Permission Boundaries

**Permission Boundaries** limit maximum permissions an identity can have, EVEN with explicit allows.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudwatch:*",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
```

- Apply the boundary:

```bash
aws iam put-user-permissions-boundary \
  --user-name DevUser \
  --permissions-boundary arn:aws:iam::123456789012:policy/DeveloperBoundary
```

### Service Control Policies (SCPs)

Organizational-level policies that set maximum permissions for accounts.

- Explicitly deny users ability to launch any EC2 instance type other than `t2.micro`, `t2.small`, `t3.micro`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": [
            "t2.micro",
            "t2.small",
            "t3.micro"
          ]
        }
      }
    }
  ]
}
```

### Policy Conditions

- **IP Address Restrictions**:

```json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["203.0.113.0/24", "198.51.100.0/24"]
    }
  }
}
```

- **MFA Required**:

```json
{
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

- **Tag-Based**: Includes both `Global condition key` and Resource Tag Key. Allow statemnt only if the target is `us-east-1` region AND there is a tag `Project:DataPipeline`.

```json
{
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "us-east-1",
      "ec2:ResourceTag/Project": "DataPipeline"
    }
  }
}
```

## IAM Roles

**IAM Roles** are Identities with permissions policies that define what actions can be performed on which AWS resources. Roles are not associated with a single person and **can be assumed by any user, AWS service, applications and users from other AWS accounts**.

### Roles Characteristics

- **Temporary Credentials**: Roles provide temp security credentials that are dynamically created when you assume the role.
- **No Long-Term Credentials**: Roles don't have standard long-term crednetials like passwords or access keys.
- **Federated Access**: Support for identity federation from corporate directories or web identity providers.
- **Cross-Account Access**: Enable secure delegation between AWS Accounts.

### Trust Policy (AssumeRole Policy)

- Principal.Service: Specifies the AWS service EC2 can assume the role.
- Action: sts:AssumeRole: is the only valid action in trust policies.
- This trust policy MUST be attached to the role, while permissions policies determine what the role can do.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Cross Account: Complete Flow

1. Create Policy in Account B: 
- Lets you run `aws sts assume-role --role-arn arn:aws:iam::123456789012:role/CrossAccountRole`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::123456789012:role/CrossAccountRole"
    }
  ]
}
```

- Assign some Permissions Policy: Gives `s3:ListBucket`

```bash
# Attach a managed policy to the role
aws iam attach-role-policy \
  --role-name CrossAccountRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

2. Get Temporary Credentials:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/CrossAccountRole \
  --role-session-name MySession
```

- Response will be:

```json
{
  "Credentials": {
    "AccessKeyId": "EXAMPLE",
    "SecretAccessKey": "EXAMPLE",
    "SessionToken": "EXAMPLE...",
    "Expiration": "2024-01-01T00:00:00Z"
  },
  "AssumedRoleUser": {
    "AssumedRoleId": "ABCEXAMPLE:MySession",
    "Arn": "arn:aws:sts::123456789012:assumed-role/CrossAccountRole/MySession"
  }
}
```

3. Use Credentials (Now that you are in CrossAccountRole)

```bash
# Export the temporary credentials
export AWS_ACCESS_KEY_ID=EXAMPLE
export AWS_SECRET_ACCESS_KEY=EXAMPLE
export AWS_SESSION_TOKEN=EXAMPLE....

# Now you can do whatever CrossAccountRole allows
aws s3 ls s3://account-a-bucket/   # Works IF CrossAccountRole has s3:ListBucket
aws ec2 describe-instances         # Works IF CrossAccountRole has ec2:DescribeInstances
aws dynamodb list-tables           # FAILS IF CrossAccountRole doesn't have dynamodb permissions
```

- Account B, your side, contains `sts:AssumeRole` permission only; and Account A, Target Account, contains actual Resource permissions attached to the role. **The role wears the permission when you assume it**.

## AWS Identity Center (SSO)

## Security Best Practices

## Patterns and IAC