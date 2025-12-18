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

### Architecture Overview

```text
┌─────────────────┐
│  Identity Store │ ◄─── Corporate IdP (SAML 2.0)
│   (Directory)   │      (Okta, Azure AD, etc.)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  AWS IAM        │
│  Identity Center│
└────────┬────────┘
         │
         ├──► Account 1 (Production)
         ├──► Account 2 (Development)
         └──► Account 3 (Staging)
```

1. Use an existing **"source of truth"** for identities like `Okta`, `Google Workspace` or `Azure AD/EntraID` to manage access across an entire AWS organization. `SAML 2.0` for authentication. Once user is deactivated from the IdP, their access to AWS is revoked instantly.

2. **Identity Store**: The local directory in AWS for representation to assign AWS permissions. A protocol called `SCIM` is used to automatically push users and groups from corporate IdP. It holds metadata (Usernames, Group Memberships).

3. **AWS IAM Identity Center**: The control plane where you define who gets into which account and what they can do. Create **permission sets**/templates (e.g. `ReadOnlyAccess`, `AdministratorAccess`). Create a rule that says which groups get which permission sets.

4. **Target Accounts (Production, Dev, Staging)**: **IAM Identity Center** automatically reaches into your account where you assign a Permission Set and create a special IAM role (i.e. `AWSReservedSSO...`). Users see a list of accounts in the Portal, and click one to trigger a *federated identity login*.

### Permission Sets

Permission Sets are templates that define what users can do in AWS.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "rds:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "ec2:*Spot*"
      ],
      "Resource": "*"
    }
  ]
}
```

### SSO CLI Configuration

```bash
# Configure SSO profile
aws configure sso
# SSO start URL: https://my-company.awsapps.com/start
# SSO Region: us-east-1
# Account: 123456789012
# Role: DeveloperAccess
# CLI profile name: dev-account

# Login
aws sso login --profile dev-account

# Use profile
aws s3 ls --profile dev-account
```

## Security Best Practices

### Enforce MFA

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptListedIfNoMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

### Principle of Least Privilege

Start with Deny-by-Default and grant minimal permissions.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/users/${aws:username}/*"
    }
  ]
}
```

### IAM Roles

- Use IAM roles in Applications without the need for explicit credentials:

```python
# Using IAM role (implicit credentials)
import boto3
s3 = boto3.client('s3')
```

### Rotate Credentials Regularly

```bash
# List access keys older than 90 days
aws iam list-access-keys --user-name MyUser --query \
  'AccessKeyMetadata[?CreateDate<=`'$(date -d '90 days ago' -I)'`]'

# Create new key
aws iam create-access-key --user-name MyUser

# Delete old key
aws iam delete-access-key --user-name MyUser --access-key-id AKIAIOSFODNN7EXAMPLE
```

### Enable CloudTrail Logging

```bash
# Create trail
aws cloudtrail create-trail \
  --name SecurityAuditTrail \
  --s3-bucket-name my-cloudtrail-bucket \
  --is-multi-region-trail \
  --enable-log-file-validation

# Start logging
aws cloudtrail start-logging --name SecurityAuditTrail
```

## Patterns and IAC

### Attribute-Based Access Control

- Use Tags to control access:

```bash
# Tag EC2 instance
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=Project,Value=DataPipeline Key=Environment,Value=dev

# Tag user
aws iam tag-user \
  --user-name developer1 \
  --tags Key=Project,Value=DataPipeline Key=Environment,Value=dev
```

- ABAC Policy: User can perform actions on all resources, **IF the tags on the user match the tags on the server**.

```json
// ABAC policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:RebootInstances"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Project": "${aws:PrincipalTag/Project}",
          "ec2:ResourceTag/Environment": "${aws:PrincipalTag/Environment}"
        }
      }
    }
  ]
}
```

### Credential Reports

```bash
# Generate report
aws iam generate-credential-report

# Download report
aws iam get-credential-report --output text --query Content | base64 -d > report.csv
```

### Role Chaining

```bash
# Assume first role
credentials=$(aws sts assume-role \
  --role-arn arn:aws:iam::111111111111:role/Role1 \
  --role-session-name session1)

# Export credentials
export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $credentials | jq -r '.Credentials.SessionToken')

# Assume second role
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/Role2 \
  --role-session-name session2
```

### Terraform: IAM User Programmatic Access

```h
resource "aws_iam_user" "developer" {
  name = "developer1"
  path = "/developers/"
  
  tags = {
    Project     = "DataPipeline"
    Environment = "dev"
  }
}

resource "aws_iam_access_key" "developer_key" {
  user = aws_iam_user.developer.name
}

resource "aws_iam_user_policy_attachment" "developer_policy" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

output "access_key_id" {
  value     = aws_iam_access_key.developer_key.id
  sensitive = true
}

output "secret_access_key" {
  value     = aws_iam_access_key.developer_key.secret
  sensitive = true
}
```

### Terraform: IAM Role for EC2

```h
# Trust policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM role
resource "aws_iam_role" "ec2_role" {
  name               = "EC2-S3-Access-Role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  
  tags = {
    Purpose = "EC2 instances accessing S3"
  }
}

# Permission policy
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    
    resources = [
      "arn:aws:s3:::my-data-bucket",
      "arn:aws:s3:::my-data-bucket/*"
    ]
  }
}

resource "aws_iam_policy" "s3_access_policy" {
  name   = "S3AccessPolicy"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-Instance-Profile"
  role = aws_iam_role.ec2_role.name
}

# Attach to EC2 instance
resource "aws_instance" "app_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  
  tags = {
    Name = "AppServer"
  }
}
```