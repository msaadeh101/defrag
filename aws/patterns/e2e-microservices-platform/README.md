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
    - User Service:
    - Order Service:
    - Notification Service:
    - Analytics Service:
- **Lambda functions for S3 event processing**.
    - File Upload Hanlder:
    - Batch Data Ingestion:
    - Cost Efficiency:
    - Flow: User uploads `invoice.pdf` -> S3 Event -> Lambda extracts text (OCR) -> SQS -> Order Service EKS -> RDS
- **SQS queues with DLQ for reliable messaging processing**.
    - Async Processing: Decouples services to prevent cascading failures (i.e. don't wait for notification service, publish to SQS and return 201).
    - Retry Logic: Temporary DB connection issue allows for up to 3 retries before moving to DLQ.
    - Backpressure Management: Messages queue up without data loss, consumers scale via HPA based on queue depth metric.
    - Guaranteed Delivery: At-least-once-delivery protects against pod restarts and node failures.
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


## Data Flow

```txt
Client -> ALB -> Istio Ingress Gateway -> Istio SideCar -> API microservice
```

1. **EntryPoint: ALB + Istio Gateway**
- **ALB**: The "Outer Door", handles WAF, public facing SSL termination, AWS Shield for DDoS protection.
- **Istio Gateway**: The "Inner Door", Receives traffic from ALB and manages internal routing logic, retries, JWT validation before request hits your API.

2. **Service Mesh: Istio**
- **mTLS**: By default, Istio encrypts traffic between microservices.
- **JWT Validation**: Additional layer for defense in depth via `RequestAuthentication` and `AuthorizationPolicy` objects.

3. **Security: Addons for Identity Layer**
- **Cert-Manager**: Handles SSL certificates (via Let's Encrypt) and rotates automatically.
- **Secrets Manager**: Secrets Store CSI Driver to mount RDS password/API Keys as env vars.