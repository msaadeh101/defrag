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

## Network Design

## Security and Access Control

## Troubleshooting and Examples