# E2E AWS Microservices Architecture

## Architecture Overview

- **Compute**: EKS 1.33, Karpenter (Node Provisioning)
- **Service Mesh**: Istio 1.27 for traffic management, mTLS
- **Ingress**: AWS ALB and Istio for external traffic
- **Security**: Cert-Manager for TLS, AWS Secrets Manager, Istio for JWT validation
- **Storage**: RDS PostgreSQL, DynamoDB, ElastiCache Redis
- **Messaging**: SQS for async processing
- **Observability**: CloudWatch, X-Ray, Prometheus/Grafana

### Services and Integrations

- **Java/Spring Boot microservices**.
    - **User Service**: Manage user profiles, authentication state, preferences. Uses redis for caching to reduce database load on read operations. Publishes user lifecycle events to SQS downstream.
    - **Order Service**: Database transactions in RDS for ACID compliance. Maintains order state machine.
    - **Notification Service**: Decoupled from core business logic, consumes events from SQS queues to publish emails/SMS.
    - **Analytics Service**: Reads from DynamoDB for fast session analytics/user behavior tracking. Real-time dashboards due to ns latency.
- **Lambda functions for S3 event processing**.
    - **File Upload Hanlder**: Trigger from S3 PUT event. Validates file format, scans for malware, extracts metadata, publish to SQS.
    - **Batch Data Ingestion**: Process nightly dumps from X partner.
    - **Cost Efficiency**: Pay-per-invocation for sporadic S3 events.
    - **Flow**: User uploads `invoice.pdf` -> S3 Event -> Lambda extracts text (OCR) -> SQS -> Order Service EKS -> RDS
- **SQS queues with DLQ for reliable messaging processing**.
    - **Async Processing**: Decouples services to prevent cascading failures (i.e. don't wait for notification service, publish to SQS and return 201).
    - **Retry Logic**: Temporary DB connection issue allows for up to 3 retries before moving to DLQ.
    - **Backpressure Management**: Messages queue up without data loss, consumers scale via HPA based on queue depth metric.
    - **Guaranteed Delivery**: At-least-once-delivery protects against pod restarts and node failures.
- **ALB + Istio for multi layered microservice security**.

### Data Layer

- **RDS PostgreSQL for business data**.
    - **Why PostgreSQL**: Transactional data requiring ACID. Complex queries with JOINs, FK Constraints and transactions. Relational model fits normalized business data.
    - **HA and Backup**: Multi-AZ deployment and synchronous replication. Auto failover if primary fails. 7-day automated backups with PIT recovery.
    - **Example Schema**: **Users table** (`id`, `email`, `password_hash`), **Orders table** (`id`, `user_id FK`, `total`, `status`), **OrderItems table** (`id`, `order_id FK`, `product_id`, `quantity`).
    - **Connection Pooling**: HikariCP in SpringBoot maintains 20 connections per pod. 10 pods = 200 connections managed efficiently.
- **DynamoDB for sessions**.
    - **Why DynamoDB**: Storing user session data (JWT claims, cart contents, preferences) with single-digit ms latency at any scale. No capacity planning with on-demand billing. TTL auto expires old sessions.
    - **Example Schema**: **Partition key** = `sessionId` (UUID), `userId` GSI for querying all sessions for a user. **TTL attribute** = `expiresAt` (Unix timestamp).
    - Example Data: `{sessionId: "abc123", userId: "user_456", cartItems: [...], createdAt: 1703001234, expiresAt: 1703087634}`
- **Elasticache Redis for caching**.
    - **Why Redis**: In-memory data store with micro-second latency supporting strings, hashes, lists, sets, sorted sets. Applications check redis first, on miss checks RDS.
    - **Session Sharing**: Multiple User service pods share session state WITHOUT sticky sessions at ALB.

### Best Practices Implemented

- IRSA for pod-level AWS permissions.
- External Secrets Operator for secure secrets management.
- HPA and PDB for availability during scaling/updates.
- Multi-AZ Deployments for all services for redundancy.
- Pod anti-affinity for zone distribution.
- Limit logging and tracing to necessary only to limit ballooning costs.

## CICD Overview

- **GitOps Principles**: Everything but credentials live in Git
- **Environment Separation**: Base + Overlays pattern with Kustomize
- **Ownership Model**: CODEOWNERS provides clear responsibility at file level
- **Automated Promotion**: CI Passes -> ArgoCD and PR triggered Deployments
- **Secret Management**: External Secrets Operator and Github Environments

## Considerations

- **EKS Versions**: Minor K8s versions are under standard support for EKS for 14 months after release. Extended support for 12 months, at additional cost. Current standard support versions (Jan 2026): 1.32-1.34.

- **EKS Scaling**: Managed Node Groups are controled by AWS Auto Scaling Groups (ASGs), and follow the `min`/`max`/`desired` defined in IAC. Karpenter is a Groupless autoscaler that bypasses ASGs and talks to EC2 Fleet API directly based on pending pod requirements. Karpenter itself runs in the mangaged node groups.

- **Istio Versions**: Istio 1.28 is the latest as of Jan 2026, and supports K8 versions 1.30-1.34. 1.27 is supported until Apr 2026 and goes up to k8 1.33.

- **Certificate Managemet**: `cert-manager` consumes IRSA/Pod Identity and creates the K8 secret (in `istio-ingress` ns) for Istio Gateway. Issuer and Certificate are defined separately. `dns01` is chosen as the challenge type because it allows for wildcard certificates, and doesn't require a Load Balancer to be reachable for validation.


## Traffic Flow

```txt
Client -> ALB -> Istio Ingress Gateway -> Istio SideCar -> API microservice

Internet Client (browser)
  ↓ [TLS 1.3 - HTTPS with ACM cert: *.mycomp.org]
AWS ALB (terminates TLS)
  ↓ [HTTP or re-encrypted HTTPS with cert-manager cert]
Istio Ingress Gateway
  ↓ [mTLS with Istio-managed certs]
Backend Microservices
```

1. **EntryPoint: ALB + Istio Gateway**
- **ALB: The "Outer Door"**:
    - Handles WAF rules, Rate Limiting, AWS Shield Standard for DDoS protection.
    - Public facing SSL termination with ACM cert `*.mycomp.org` trusted by all browsers.
    - Health Checks to Istio Ingress Gateway pods. 
    - Can optionally re-encrypt traffic to Istio Gateway (HTTPS -> HTTPS) or send plain HTTP over private VPC network.
- **Istio Gateway: The "Inner Door"**:
    - Receives traffic from ALB (HTTP or HTTPS).
    - Manages internal routing logic via VirtualServices (path-based, header-based, weight-based).
    - Enforces retries, timeouts, circuit breaking before requests hit backend services. 

2. **Service Mesh: Istio**
- **Automatic mTLS between services**:
    - Istio generates own internal certs using built-in CA Citadel.
    - Every pod gets a unique X.509 certificate fully handled via the Envoy sidecar. Rotated automatically every 24 hours.
- **JWT Validation (Optional)**: 
    - Defense-In-Depth: Even if traffic reaches your service, JWT must be valid.
    - Configured via `RequestAuthentication` (JWT Sig) and `AuthorizationPolicy` (JWT Claims) objects.
    - Example: Only allow requests with `role: admin` to reach `/api/admin/*`

3. **Certificate Management Layers**
- **cert-manager**: Issues certs for Istio Gateway (ALB->Istio) via Let's Encrypt.
- **Istio CA (Citadel)**: Issues certificates for pod-to-pod mTLS within mesh, fully automated, no external CA needed.
- **ACM**: Issues certificates for ALB (Internet->ALB). Managed by AWS, auto-renewal.

4. **Secrets Management**
- **AWS Secrets Manager + External Secrets Operator**: Syncs secrets (RDS passwords, API keys) from AWS Secrets Manager into K8 Secret objects. Recommended for K8 native/audit trails.
- **Secrets Store CSI Driver (Alternative)**: Mounts secrets directly as files in pods without creating K8s Secret objects.