# AWS VPC

## VPC Fundamentals

**VPC** is a logically isolated network environment within AWS where you launch and manage resources. It gives you control over IP address ranges, subnet layout, route tables, and network gateways.

### Key Characteristics

- **Isolation**: Each VPC is logically isolated. You only get connectivity between VPCs via explicit VPC Peering, Transit Gateway, PrivateLink (which you need to self-configure).
- **CIDR Block**: Specify an IPv4 CIDR block between `/16` (65,536 addresses) and `/28` (16 addresses). You can later attach additional, NON-OVERLAPPING CIDR blocks if you outgrow the original range.
- **Region Scoped**: VPCs are created within a **single AWS region (spans all AZs)**. Cross-region connectivity requires peering, Transit Gateway, or other networking constructs.
- **Tenancy**: Default is shared hardware, or Dedicated single-tenant hardware, useful for compliance or licensing.
- **IPv6 Support**: Optional IPv6 CIDR block can be associated. This enables dual-stack operation, where subnets, route tables, and resources have both IPv4 and IPv6 addresses, designing future-ready architecture without abandoning IPv4 workloads.

### VPC Components

#### Internet Gateway (IGW)

- Horizontally scaled, redundant, highly available VPC component that allows communication between VPC (public subnets) and the internet.
- Only one IGW per VPC, but you can attach and dettach them as needed or use different IGWs.
- It's attached at the VPC level and must be referenced in a route table (`0.0.0.0/0 -> igw-xxxxx`) to make the subnet "public".
- No Bandwidth constraints or need to manage capacity. You pay only for standard data transfer charges for traffic in/out of AWS.

#### NAT Gateway

- Managed Network Address Translation service for instances in private subnets to initiate outbound connections to the internet (for updates/APIs, etc) while preventing unsolicited inbound connections from the internet.
- Deployed in a specific subnet and AZ, usually public, and traffic from private subnets is routed via route table entries (`0.0.0.0/0 -> nat-xxxx`).
- For HA, deploy one NAT per AZ and route private subnets in each AZ to the local NAT Gateway, avoiding cross-AZ dependency.
- Scales automatically up to 45 Gbps, very high before any limits are encountered.
- Cost is hourly + data processing fee: `$0.045/hour + $0.045/GB data processed`
- Legacy option is NAT instance (EC2 acting performing NAT).

#### Virtual Private Gateway (VGW)

- A VGW is the VPN endpoint on AWS side for Site-to-Site VPN connections that terminate into a VPC.
- Acts as a VPN concentrator on AWS, establishing IPSec tunnels between your on-prem customer gateway device and your VPC.
- Each site-to-site VPN connection typically uses two tunnels for redundancy, each with low Gbps throughput usually.
- You can attach a VGW to a single VPC and multiple VPN connections can share the same VGW, enabling hub-and-spoke designs between a VPC and multiple on-prem locations.
- VGW-based VPNs are used for hybrid connectivity where a dedicated AWS Direct Connect Link is not justifyible.
- For multi-VPC environments, or if using a Transit Gateway, you can connect the VGW to a Transit Gateway instead of directly to each VPC.

#### Transit Gateway (TGW)

- A TGW is a regional network transit hub that simplifies connecting multiple VPCs and on-prem networks.
- Supports centralized routing and management by attaching VPCs and VPNS (Direct Connect GWs) to a single TGW, instead of a mesh of VPC peering connections.
- Supports thousands of attachments, including VPCs, VPNs, Direct Connect Gateways, depending on the region and limits..
- Inter-region peering between TGWs lets you extend the Hub-and-Spoke architecture across regions using AWS backbone links.
- TGW is a paid service with per-attachment hourly charges and per-GB processing charges.

### VPC Resource Limits

|Resource |Limits|
|----------|------|
| VPCs per region|  5 (can increase to 100+)| 
| Subnets per VPC| 200 (Adjustable)| 
| Elastic IPs per region| 5 (Adjustable)| 
| Internet Gateways per region|  5 (tied to VPC limit/ 1 per VPC)| 
| Route tables per VPC| 200 (Adjustable)| 
| Routes per route table|  500 default for non-propagated, 100 (total)| 
| Security groups per VPC|  2,500 per Region| 
| Rules per security group| 60 inbound, 60 outbound| 
| Network ACLs per VPC|  200| 
| Rules per NACL|  20| 
| VPC peering connections per VPC|  Default is 50, Max is 125| 

### Private IP Ranges

RFC 1918 IP Ranges and values:

```txt
10.0.0.0/8      (10.0.0.0 - 10.255.255.255)     16,777,216 IPs
172.16.0.0/12   (172.16.0.0 - 172.31.255.255)   1,048,576 IPs
192.168.0.0/16  (192.168.0.0 - 192.168.255.255) 65,536 IPs
```

## Subnets Architecture

A **subnet** is a range of IPs within your VPC. Subnets are created **within a single Availability Zone** and cannot span AZs.

- AWS Reserves 5 IPs in each subnet For example, /24 (256 IPs): `.0 - Network`, `.1 - VPC Router`, `.2 - Route 53 Resolver`, `.3`, .`255` are reserved.


### Subnet Types

The Type of Subnet is SOLELY determined by its Route Table associations.

| Subnet Type	| Primary Route Table Entry	| Connectivity Feature| Use Case |
|-----------|-----------|------------------|----|
| **Public**	| `0.0.0.0/0` -> `igw-xxxxxxxx`	| Supports Public IPs and Elastic IPs. Accessible from the internet.| Load Balancers, Bastion Hosts, NAT Gateways.|
| **Private**	| `0.0.0.0/0` -> `nat-xxxxxxxx`	| Uses a NAT Gateway in a Public subnet for outbound-only internet.| App Servers, Databases, Internal services.|
| **Isolated**| 	No `0.0.0.0/0` route|	Traffic stays within the VPC or via VPC Endpoints (PrivateLink).| Compliance/Sensitive data| 

### Subnet Design Patterns

#### Three-Tier Architecture

```md
**VPC**: `10.0.0.0/16`

**Public Subnets (DMZ)**:
  `10.0.1.0/24`  (us-east-1a) - Web tier / ALB
  `10.0.2.0/24`  (us-east-1b) - Web tier / ALB
  `10.0.3.0/24`  (us-east-1c) - Web tier / ALB

**Private Subnets (Application)**:
  `10.0.11.0/24` (us-east-1a) - App servers
  `10.0.12.0/24` (us-east-1b) - App servers
  `10.0.13.0/24` (us-east-1c) - App servers

**Private Subnets (Database)**:
  `10.0.21.0/24` (us-east-1a) - RDS, ElastiCache
  `10.0.22.0/24` (us-east-1b) - RDS, ElastiCache
  `10.0.23.0/24` (us-east-1c) - RDS, ElastiCache
```

#### Multi-Account (Hub-And-Spoke)

```md
**Shared Services VPC**: `10.0.0.0/16`
  - Central egress (NAT)
  - Shared services (DNS, monitoring)
  
**Production VPC**: `10.1.0.0/16`
  - Connected via Transit Gateway
  
**Development VPC**: `10.2.0.0/16`
  - Connected via Transit Gateway
```

### Route Tables

**Route tables** contain rules (routes) that determine where network traffic is directed.
- **Each subnet must be associated with a route table**.

Route Priority
1. Local Routes (VPC CIDR)
2. Most Specific routes (longest prefix match)
3. Static routes over propagated routes.
4. If equal specificity: Static -> VGW propagated -> Transit Gateway

```md
# Public Subnet RT
Destination       Target
10.0.0.0/16      local
0.0.0.0/0        igw-xxxxx


# Private Subnet RT
Destination       Target
10.0.0.0/16      local
0.0.0.0/0        nat-xxxxx
10.1.0.0/16      pcx-xxxxx  (VPC Peering)
192.168.0.0/16   vgw-xxxxx  (VPN)

```

## VPC Endpoints (PrivateLink)

**VPC Endpoints** enable private connections between your VPC and AWS services without requiring an Internet Gateway, NAT device, VPN connection, or AWS Direct Connect.
- Traffic between your VPC and the service does not leave the Amazon network.

### Interface Endpoints

- Powered by AWS PrivateLink, uses **DNS** to route traffic.
- Elastic Network Interface (ENI) with private IP.
- Supports most AWS services and customer/third-party services
- Charged per hour + data processed ($0.01/hour/AZ + $0.01/GB)
- Supports Security Groups

| DNS Type	|Description	|DNS Name|
|-----------|------------|--------|
|**Regional DNS** |	Regional VPC endpoint DNS name (routes within the region)|	`vpce-0123456789abcdef-abc123de.ec2.us-east-1.vpce.amazonaws.com`|	
|	**Zonal DNS** | **(AZ: us-east-1a)**	AZ-specific VPC endpoint DNS name	|`vpce-0123456789abcdef-abc123de-us-east-1a.ec2.us-east-1.vpce.amazonaws.com`|
|**Service DNS**	|Standard AWS service DNS **(overridden by Private DNS when enabled)**	|`ec2.us-east-1.amazonaws.com`|

**Private DNS**:
- When enabled, AWS service DNS names resolve to endpoint IPs.
- Requires `enableDnsHostnames` and `enableDnsSupport` on VPC.
- Transparently routes traffic through endpoint.

### Gateway Endpoints

- Only supports **S3** and **DynamoDB**.
- **Route table-based routing**, No ENI, no IP address.
- FREE.
Regional resource (spans all AZs)
- **Cannot be extended out of VPC**

**Example Route Table Entry**:

```txt
Destination              Target
pl-63a5400a (S3)        vpce-xxxxx
pl-78a54011 (DynamoDB)  vpce-yyyyy
# Prefix List (PL) Manafed and updated by AWS for service IP ranges.
```

### Gateway Load Balancer Endpoints

- For third-party virtual appliances
- Transparent network gateway
- Traffic inspection, IDS/IPS, firewalls
- Uses **GENEVE** protocol.

### Endpoint Policies

You can manage VPC Interface or Gateway Endpoints with policies attached to them.
- **Endpoint policies control service API actions**, not IAM actions (IAM policies do not allow `Principal`).
- Below restricts access to identities in a specific organization.

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/AppRole"
      },
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-xxxxxxxxxx"
        }
      }
    }
  ]
}
```

## Network Design

### General Network Design

```txt
Internet Gateway
    ↓
Network Firewall (Inspection VPC)
    ↓
Transit Gateway
    ↓
Application VPCs
```

### Single VPC Multi-Tier

- Simple architecture/management, low-latency between tiers.
- Limited network segregation.

```txt
VPC: 10.0.0.0/16
├── Public Subnets (NAT, ALB)
├── Private Subnets (Compute)
└── Isolated Subnets (Databases)

Internet → IGW → ALB → EC2 → RDS
                ↓
              NAT → Internet (outbound)
```

### Multi-VPC with Peering

- Multiple environments (Dev, stage, prod) with different compute/compliance requirements.
- Cross-region supported.
- Shared services environment for CICD, observability, etc.
- **VPC Peering is Non-transitive**: A-B and B-C does not equal A-C.

```txt
Prod VPC (10.0.0.0/16) ←→ Shared Services VPC (10.1.0.0/16)
                            ↕
Dev VPC (10.2.0.0/16)  ←→ Shared Services VPC
```

### Transit Gateway Hub-And-Spoke

- Use for large number of VPCs (> 10) and a need for **Transitive Routing**/ **Hybrid Connectivity** / Multi-Account.
- Centralizes routing, transitive routing supported. Scalable with 5000+ VPC attachments.
- Allows for simplified network topology and Inter-region peering.
- **Expensive at Scale** ($.05/hour/attachment and $.02/GB data processed)

```txt
        Transit Gateway
       /    |    |    \
      /     |    |     \
  VPC-A  VPC-B VPC-C  VPN/DX(Direct Connect)

# TGW acts as a cloud router, everything communicates via the TGW  
```

### VPC Sharing

- **Requires AWS Organizations**.
- Use for multiple AWS accounts in an **Organization**, or when you want to share Network infrastructure.
- Centralized network/IP management and optimized cost (less VPCs, share NAT/endpoints).

```txt
Network Account (Owner)
  └── Shared VPC
        ├── Shared to Account A (uses subnets)
        ├── Shared to Account B (uses subnets)
        └── Shared to Account C (uses subnets)
```


### Egress VPC (Centralized NAT)

- Use to centralize egress monitoring, **require traffic inspection**, and you want to reduce NAT gateway costs.
- Can lead to **significant cost reduction** over traditional VPC spread across AZs

```txt
Transit Gateway
  ├── Egress VPC (NAT Gateways)
  ├── Prod VPC → routes to TGW for 0.0.0.0/0
  └── Dev VPC → routes to TGW for 0.0.0.0/0
```

## Security and Access Control

### Security Groups

- Instance-level firewall.
- Stateful (return traffic is automatically allowed).
- All rules are ALLOW rules (no DENY).
- All rules are evaluated first.
- Default: Deny all inbound, allow all outbound.

#### Three-Tier Security Groups

```txt
ALB Security Group:
  Inbound: 443 from 0.0.0.0/0
  Outbound: All to App-SG

App Security Group:
  Inbound: 8080 from ALB-SG
  Outbound: 3306 to DB-SG
            443 to VPC Endpoint SG

DB Security Group:
  Inbound: 3306 from App-SG
  Outbound: None needed (stateful)
```

### Network ACL (Stateless)

- Subnet-level firewall.
- Stateless (must allow return traffic explicitly).
- Rules evaluated in order, first match wins.
- ALLOW and DENY rules supported.
- Default NACL: Allow all inbound/outbound.

#### Private NACL

```txt
Inbound Rules:
  100: Allow TCP 443 from 10.0.0.0/16 (HTTPS)
  110: Allow TCP 22 from 10.0.1.0/24 (SSH from bastion)
  120: Allow TCP 1024-65535 from 0.0.0.0/0 (Return traffic)
  *: Deny all

Outbound Rules:
  100: Allow TCP 443 to 0.0.0.0/0 (HTTPS)
  110: Allow TCP 3306 to 10.0.21.0/24 (MySQL)
  120: Allow TCP 1024-65535 to 0.0.0.0/0 (Return traffic)
  *: Deny all
```

## Troubleshooting and Examples

### VPC Flow Logs

Caputres IP traffic metadata flowing to and from network interfaces in the VPC. 
- Good for security analysis/threat detection/compliance/audititing/cost optimization.
1. VPC Level: All ENIs in VPC.
2. Subnet Level: All ENIs in subnet.
3. ENI Level: Specific ENI only.

- Send to CloudWatch, S3 or Kinsesis Data Firehose.

#### VPC Flow Logs in CloudWatch Insights

```s
# Top 20 IPs by bytes
fields @timestamp, srcAddr, dstAddr, bytes
| sort bytes desc
| limit 20

# Rejected SSH attempts
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort
| filter dstPort = 22 and action = "REJECT"

# Traffic to/from specific IP
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter srcAddr = "10.0.1.50" or dstAddr = "10.0.1.50"
```


```bash
# Default Format:
${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}

# Custom Format (example):
${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${action} ${flow-direction}
```

#### VPC Flow Logs Analysis

```bash
# Analyze rejected traffic
aws logs filter-log-events \
  --log-group-name /aws/vpc/flowlogs \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]'
```

### VPC Traffic Mirroring

Copy network traffic from ENIs for monitoring and security analysis, content inspection, and more.

1. **Source**: ENI to mirror
2. **Target**: ENI or Network Load Balancer
3. **Filter**: What traffic to mirror

### Check Private DNS

- PrivateDNS is the mechanism that allows AWS PrivateLink to reach services over AWS backbone using DNS.

```bash
# Check if private DNS is working
nslookup s3.us-east-1.amazonaws.com

# Should return private IPs from your VPC CIDR, not public AWS IPs
# Example output:
# Name:    s3.us-east-1.amazonaws.com
# Address: 10.0.1.45
# Address: 10.0.2.67
```

### Issues Checklist

#### SSH/RDP to Instance

```txt
Checklist:
- Instance in public subnet with public IP or EIP?
- Route table has route to IGW (0.0.0.0/0 → igw-xxx)?
- Security group allows inbound SSH (22) or RDP (3389)?
- NACL allows inbound/outbound traffic?
- Instance has OS-level firewall rules?
- Key pair correct for SSH?
- Windows password retrieved for RDP?
```

#### Private Instance To Internet

```txt
Checklist:
- NAT Gateway in public subnet?
- NAT Gateway has Elastic IP?
- Private subnet route table has 0.0.0.0/0 → nat-xxx?
- Security group allows outbound traffic?
- NACL allows ephemeral ports (1024-65535) inbound?
```

#### VPC Peering

```txt
Checklist:
- Peering connection status is "Active"?
- Route tables updated on both sides?
- No overlapping CIDR blocks?
- Security groups allow traffic from peer VPC?
- NACLs allow traffic?
- DNS resolution enabled (if using DNS)?
```