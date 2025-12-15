# Control Tower


## Overview and Concepts

**AWS Control Tower** is a managed service that automates the setup of a secure, multi-account AWS environment following prescriptive AWS best practices (a landing zone). (`AWS Organizations + Gaurdrails + Automation`)

A Control Tower **Landing Zone** is a governed, multi account environment build on AWS Organizations best practices. Accounts are organized into **Organizational Units (OUs)** to apply policies (**Gaurdrails**) consistently across workloads.

```text
┌─────────────────────────────────────────────────────────┐
│                   Control Tower Core                    │
├─────────────────────────────────────────────────────────┤
│  • Management Account (Payer Account)                   │
│  • Log Archive Account (Centralized logging)            │
│  • Audit Account (Security & compliance monitoring)     │
│  • Shared Services OU (Optional)                        │
│  • Security OU (Optional)                               │
│  • Custom OUs (For workload isolation)                  │
└─────────────────────────────────────────────────────────┘
```

1. Mandatory Core Accounts (Foundation)

|Component	|Role and Purpose	|Key Services|
|-----------|---------------|---------------|
|**Management Account**	|The Root of the Organization and Payer.	|`AWS Organizations`, `Consolidated Billing`, `Service Control Policies (SCPs)`, and the primary account for launching `Control Tower` itself.|
|**Log Archive Account**	|Centralized, Immutable Logging Repository.|	Contains a dedicated S3 bucket for storing: `AWS CloudTrail` logs (all API activity across all accounts) and `AWS Config` configuration history for long-term retention and audit integrity. Access is highly restricted.|
|**Audit Account**	|Security and Compliance Monitoring Access Point.|	Used by the security team for programmatic read-only access to perform audits and security operations across all accounts. Delegated administrator for centralized security services.|

2. **Organizational Units (OUs)**
- **Security OU (Foundational)**: By default, contains **Log Archive** and **Audit** accounts.
- **Shared Services OU (Recommended)**: Accounts that host centralized services consumed by other workload accounts in the organization. Prevents unnecessary resource duplication.
    - **Networking**: Shared Transit Gateway, centralized VPC endpoint services, or DNS resolution hubs.
    - **Identity**: Centralized IAM Identity Center (AWS SSO) or federated identity providers.
    - **Tooling**: Central CI/CD tools (Jenkins, GitLab runners) or artifact repos (docker registries)
- **Workloads OU (Main Structure)**: Logically group accounts based on business function, environment or team (`development`, `production`, `sandbox`)

3. **Account Factory and Governance (Automation)**
- **Account Factory**: Self-service tool (backed by **AWS Service Catalog**) that allows users to provision new, pre-configured accounts into any of the OUs.
- **Gaurdrails (Policies)**: Rules that Control Tower enforces across the accounts.
    - **Preventative**: Implemented via **SCPs** (Service Control Policies) applied at the OU level. They prevent non-compliant actions (i.e. public S3 bucket).
    - **Detective**: Implemented via **AWS Config** rules. Detect non-compliant resources and report status to Control Tower dashboard (i.e. unencrypted EBS volume created)