# Istio on EKS

## Kubernetes

### Control Plane

**Control Plane (API Server)** communicates with Nodes via:
1. **API Server to Kubelet**: fetch pod logs, kubectl attach, kubelet port-forward. Terminates at the HTTPS endpoint, so to make the connection secure, provide --kubelet-certificate-authority with root cert bundle.
2. **API Server to Nodes, Pods, Services**: Defaults to HTTP, can be secured with `https:` prefix to node, pod, service in the API URL.

### Controllers

**Controllers**: loop to watch the state of the cluster, then request or make changes as needed.
- Controllers track at least one K8 resource type, where spec defines desired state.
- Once scheduled, pods become part of desired state for kubelet.
- Built-in controllers run inside the `kube-controller-manager`, but you can extend the functionality.

### Leases

**Leases**: In k8, the Lease objects come from coordination.k8.io API group, for things like Node hearbeates and leader election.
- Each `kube-apiserver` uses the Lease API to publish its own identity to the rest of the system, so you can discovery number of instances of kube-apiserver
- Inspect a lease: `kubectl -n kube-system get lease -l apiserver.kubernetes.io/identity=kube-apiserver`

### Cloud Controller Manager

**Cloud Controller Manager**: Control plane component that embeds cloud-specific control logic. It is a *structured plugin mechanism*.
- `cloud-controller-manager` allows Clouds to release features at different pace, and interacts directly with the Cloud Provider API.
- Can be run as a Kubernetes `addon`, rather than as part of the control plane.
- **Node Controllers** update Node objects when new servers are created in AWS or other clouds, responsible for annotations and labels, etc.
- **Route Controllers** configure routes in the cloud so containers on different nodes can communicate with each other. May also allocate IP blocks for Pod network.

### Cgroup v2

**cgroup v2**: Unified control system with enhanced resource management and isolation across resources.
- Choose Linux nodes with distro that enables cgroup v2 by default.
- **Pressure Stall Information** included, to see resource pressure and granularity with `some` and `full`. `sys/fs/cgroup/` where you can find `cpu.pressure`, `memory.pressure`, `io.pressure`.
- Unified accounting for different types of memory allocation (network, kernel, etc).

### Mixed Version Proxy

Mixed Version Proxy: allows an API Server proxy resource requests to other *peer* API servers.
- Useful when running different versions of Kubernetes in one cluster.
- Ensure this flag with `kube-apiserver` command: `--feature-gates=UnknownVersionInteroperabilityProxy=true` along with `--proxy-client-cert-file` and `--proxy-client-key-file`
- When you enable mixed version proxying, if the Peer API server fails, the *source* API server responds with `503 Service Unavailable`

## Istio Overview

**Istio** is an open-source service mesh that provides traffic management, security, and observability for microservices.

### Istio Features and Value Proposition

- **Traffic Management**: Advanced routing, load balancing, circuit breaking
- **Security**: mTLS, authorization policies, certificate management
- **Observability**: Distributed tracing, metrics, logs
- **AWS Integration**: Works with ALB, NLB, IAM, ACM, CloudWatch.

## Istio Basics

### Core Components

#### Istiod (Control Plane)
- Combines Pilot, Citadel, adn Galley functionality.
- Manages configuration and certificate distribution.
- Runs as a deployment in istio-system namespace.

#### Envoy Proxy (Data Plane)
- Sidecar proxy injected into application pods.
- Handles all inbound/outbound traffic.
- Implements Istio policies and telemetry.

#### Ingress/Egress Gateways
- Manage traffic entering and leaving the mesh.
- Run as standalone Envoy proxies.

### Key Concepts

1. Gateway: Traffic hits the edge.
2. VirtualService: Routing Logic (v1 vs v2, what path, etc)
3. DestinationRule: Policy Logic (How to communicate: load balancing, mTLS, circuit breaking)
4. Service Entry: Only if destination is outside cluster.

#### Gateway

**Gateway** manages external traffic entry points.
- It represents the mesh's data-plane edge, configuring Envoy proxies that handle incoming (sometimes outging) traffic at **L4/L7** such as on NLB/ALB.
- Typically deploy an **Istio Ingress Gateway Service** of type `LoadBalancer` on EKS, then bind a Gateway resource to that and attach `VirtualService` rules to control how external requests (`api.example.com`) get routed into internal services.

#### Virtual Service

**Virtual Service** defines routing rules for traffic. 
- It defines how requests to a hostname are routed once they hit the mesh (from inside the cluster or via Gateway). 
- It lets you match items like `path`, `headers`, or `source` and then send traffic to different versions (subsets) of a service for **canary**, **blue-green**, **A/B testing**.
- It also lets you apply timeouts, retries, and fault injection.
- On **EKS**, your `VirtualService` typically targets a **Kubernetes Service DNS** (for in-mesh traffic) or a host on a Gateway (for ingress) and the sidecar Envoys enforce routing rules transparently to pods.

#### Destination Rule

**Destination rule** configures load balancing and connection pools.
- It configures what happens after routing for a given service: subsets (usually mapped to labels like `version: v1`), load-balancing, connection pools, and outlier detection.
- `DestinationRule` is where you pin traffic from a `VirtualService` to specific pod sets (e.g. `subset: v2`).
- DestinationRules allow you to tune TCP/HTTP connection behavior, failover characteristics between endpoints discovered via the actual K8 service.

#### Service Entry

**Service Entry** adds external services to the mesh.
- ServiceEntry *extends the Istio service registry with endpoints that are NOT native to K8* (external APIs, legacy VMs, other clusters).
- Once a `ServiceEntry` is defined, you can use the same `VirtualService`/`DestinationRule` features (routing, timouts, mTLS to external, etc) to that external host.

#### Peer Authentication

**Peer Authentication** configures mTLS between services.
- Peer Authentication controls how workloads authenticate each other at the transport layer, mostly by configuring mTLS modes (`STRICT`, `PERMISSIVE`, `DISABLE`).
- Use PeerAuthentication to *progressively roll out mTLS cluster-wide or per-namespace/service*:
    - You enable sidecar injection
    - Set PeerAuthentication to `STRICT` for targeted workloads
    - Envoy enforces TLS handshakes and SPIFFE-based identities between pods.

#### Authorization Policy

**Authorization Policy** defines access rules.
- Specifies which principals (SAs, namespaces) can call which services, methods, or paths.
- These policies allow **zero-trust patterns** by binding rules at mesh, namespace, or workload scope,
- Example: A specific SA in `payments` can call `orders` on `/v1/*` over mTLS, regardless of underlying Kubernetes `NetworkPolicy`.

## Istio: EKS Installation


1. Install Prerequisites

```bash
aws --version
kubectl version --client
# Create the cluster with terraform
# Configure kubectl
aws eks update-kubeconfig --name my-cluster --region us-west-2
```

2. Install Istio

**Helm and Terraform Installation**:
- Add the Helm Repos for Istio (Terraform): `https://istio-release.storage.googleapis.com/charts`
- Install Istio Base (CRDs): `chart = "base"`
- Install Istio Control Plane (istiod): `chart = "istiod"`, `name = "global.proxy.image"`
- Install Istio Ingress Gateway (ALB/NLB): `chart = "gateway"`, with annotations: `"service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"`, `value = "nlb"` (Once complete, you will see an external `LoadBalancer` in istio-system namespace)
- Enable Automatic Sidecar Injection per namespace: `labels = "istio-injection" = "enabled"`. Any pod in this namespace gets the Envoy sidecar
- Deploy a Mesh App and the `VirtualService` and `Gateway` **in the same namespace as your app** from `networking.istio.io/v1alpha3`
- Include EKS Specific Addons (optional): AWS LB Controller, Karpenter, EBS CSI Driver, Prometheus Grafana, Jaeger/Tempo

**Demo Install**

```bash
# Make sure your kubeconfig is set in the right cluster
# Download Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# Install Istio with production profile
istioctl install --set profile=production -y

# Verify installation
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```
### Istio Configuration

- Then create the `istio-production.yaml` of `apiVersion: install.istio.io/v1alpha1`, `kind: IstioOperator` which defines the control plane (Istiod and gateways)
- Apply with `istioctl install -f istio-production.yaml`

```yaml
# istio-production.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-production
  namespace: istio-system
spec:
  profile: production # enables higher default replica counts, resource requests, mTLS automically
  meshConfig: # Configuration applied globally across mesh
    enableTracing: true # Collect data for Jaeger/Zipkin
    accessLogFile: /dev/stdout # Enables access logging for all sidecars, routing output to stdout
    defaultConfig:
      holdApplicationUntilProxyStarts: true # App container waits for Envoy sidecar to be ready, prevents startup connection failures
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true" # Envoy captures and forwards DNS requests so cluster-internal DNS resolution consitently happens via Istio
  components: # Allows for customization of core control plane components (Pilot/Istiod) and gateways (Ingress/Egress)
    pilot: # Refers to Istiod
      k8s:
        replicaCount: 3
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
          metrics:
          - type: Resource
            resource:
              name: cpu
              targetAverageUtilization: 80
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true # Enables default Ingress Gateway Deployment for Istio
      k8s:
        replicaCount: 3
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 20
        service:
          type: LoadBalancer # Creates an external AWS LB
          annotations:
            # NLB for higher performance and lower latency, cross-zone load balancing for even AZs distribution
            service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
            service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    egressGateways:
    - name: istio-egressgateway
      enabled: true # Enables Egress Gateway for deployment, without which traffic exits the worker node IP
      k8s:
        replicaCount: 2
  values: # Overrides configuration values applied to every Envoy sidecar proxy
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

- By deploying an `egressGateway`, you centralize and simplify egress AuthorizationPolicies, IP whitelisting, and mTLS for external services.


## IAM Integration

- **IRSA** enables workloads to assume IAM roles without storing credentials.

1. Enable IRSA on cluster

```bash
# Enable IRSA on cluster
eksctl utils associate-iam-oidc-provider \
  --cluster istio-cluster \
  --region us-west-2 \
  --approve
```


2. Create IAM policy

```bash
cat > s3-access-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name MyAppS3Access \
  --policy-document file://s3-access-policy.json
```

3. Create service account with IAM role

```bash
eksctl create iamserviceaccount \
  --name my-app-sa \
  --namespace default \
  --cluster istio-cluster \
  --region us-west-2 \
  --attach-policy-arn arn:aws:iam::ACCOUNT_ID:policy/MyAppS3Access \
  --approve
```

4. Create Manifests referencing IRSA

```yaml
# Service account example
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

## Certificate Management

Use **AWS Certificate Manager** to provision, manage and deploy your own SSL/TLS certificates for your domain, ensuring traffic is encrypted.
- Certificates you generate inside ACM (DNS or email validated) are auto-renewed/rotated/deployed and integrated into ALB/NLB/Cloudfront etc.
- The certificates ACM provides are free, publicly trusted certs.
- Autorenewal breaks if you remove the CNAME record from Route53 (or your DNS provider).
- Certificate must be in a supported region for the service
- Imported or manually created Certs must be manually renewed and rotated.

```yaml
# gateway-with-acm.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: public-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway # Standard Istio ingressGateway deployment in istio-system ns
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE # standard configuration
      credentialName: acm-certificate # When running AWS LB Controller, auto maps credentialName to ACM cert ARN attached to LB
    hosts: # Defines which domains this Gateway should accept traffic for
    - "*.example.com"
```

- Export a certificate from ACM to K8 Secret so Istio Gateway can perform local TLS termination.

```bash
# Export ACM SSL/TLS cert
# Passphrase required with ACM for exported private key
aws acm export-certificate \
  --certificate-arn arn:aws:acm:region:account:certificate/id \
  --passphrase fileb://passphrase.txt \
  --region us-west-2 > cert.json

# CRITICAL: Next steps to export private key
# 1. Parse/Decode cert.json and Base64-decode the cert, cert chain, and private key fields
# 2. Decrypt the key using OpenSSL and passphrase from txt
# 3. Format and save the plaintext cert and unencrypted private key into local files .pem(s)

# Create the Kubernetes secret
kubectl create secret tls acm-certificate \
  --cert=certificate.pem \
  --key=private-key.pem \
  -n istio-system
```

### Cert-Manager Integration

Use **Cert Manager** and **Let's Encrypt** configuration for automated, zero-touch TLS certificate issuance and renewal.
- This configuration achieves Certificate automation, TLS offloading and zero downtime.

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager -n cert-manager
```

```yaml
# letsencrypt-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme: # Let's Encrypt ACME server for obtaining certs
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef: # K8 secret for storing private key to communicate with ACME server
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio # Tells cert manager to satisfy HTTP-01 by creating a temp K8 Ingress resource
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-cert
  namespace: istio-system
spec:
  secretName: example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames: # Subject Alternative Names (SANs) specify hostnames the cert will be valid for
  - example.com # Valid for base domain
  - "*.example.com" # Valid for ALL subdomains
```

### mTLS Certificate Rotation

Istio automatically handles certificate rotation for mTLS between services.
- When a `PeerAuthentication` policy is applied to the `istio-system` namespace with name `default`, it sets the **global mesh-wide default** for peer-to-peer communication.
- By adding a specific production namespace PeerAuthentication policy, it allows for **future proofing** if global permissions were relaxed.
- **Istiod acts as a CA for the mesh**, it issues each Envoy sidecar a short-lived cert when the pod starts. Envoy periodically requests a new cert from Istiod/Citadel.

```yaml
# mtls-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT # CRITICAL: Enforces mTLS for all services in all namespaces
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: namespace-policy
  namespace: production # Targets a specicic namespace for redundancy and clarity
spec:
  mtls:
    mode: STRICT
```

- Verify mTLS status with istioctl

```bash
# Verify mTLS status
istioctl authn tls-check deployment/my-app.default
```

## Service Mesh Architecture

Service Mesh architecture in Istio on EKS is built around transparent Envoy sidecars, which intercept all Inbound and Outbound traffic for pods.
- It allows for consistent traffic management, observability and security without changing application code.
- **Isiod**, the control plane, programs the sidecars with **Istio CRDs** (`VirtualService`, `DestinationRule`, etc)

### Namespace Injection

Automatic sidecar injection uses mutating admission webhook that watches for pods in labeled namespaces and adds the Envoy containers (plus init containers) at creation.
- Use the label `istio-injection=enabled`, or a revision label for canary rollouts. Ensures that every new pod participates in the mesh.

```bash
# Enable automatic sidecar injection
kubectl label namespace default istio-injection=enabled

# Verify label
kubectl get namespace -L istio-injection

# Deploy application (sidecar injected automatically)
kubectl apply -f app.yaml -n default
```

### Manual Sidecar Injection

Manual injection uses `istioctl kube-inject` to render the pod spec with the Envoy sidecar + init containers before applying to the cluster.
- Run injection as a CICD step if needed.

```bash
# Inject sidecar manually
istioctl kube-inject -f app.yaml | kubectl apply -f -
```

### Traffic Management

Istio's traffic management model separates **where** traffic goes (`VirtualService`) from **how** it's handled (`DestinationRule` + policies).
- For EKS workloads, Envoy sidecars route based on cluster DNS (K8 services) and HTTP attributes, allowing for canary, A/B testing, and resilience without changing apps.
- Always pair a `VirtualService` with a `DestinationRule` when using **subsets**, so versioned routing is explicit and resilient.
- **VirtualService Rules are based on order**, and rules with no `match` block act as the default rule that did not match traffic for previous rules.
- Use hostnames that align with K8 services (e.g. `reviews.default.svc.cluster.local`).

#### VirtualService

```yaml
# virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: default
spec:
  hosts:
  - reviews # The target service this VS defines traffic for
  http: # HTTP/1.1 and 2 traffic
  - match: # Rule 1: High priority, user-based routing
    - headers: # matches based on specific HTTP headers
        end-user: # Looks for header 'end-user' and value 'premium' exactly
          exact: premium
    route:
    - destination:
        host: reviews
        subset: v2 # send 100% of matched traffic to v2 subset
      weight: 100
  - route: # Rule 2: Lower priority - Default/general traffic fallback
    - destination:
        host: reviews
        subset: v1 # Route 90% of traffic to stable v1 set
      weight: 90
    - destination:
        host: reviews
        subset: v2 # Route 10% of general traffic to v2 for canary
      weight: 10
```

#### DestinationRule

- Ensure DestinationRule subset labels match exactly, to avoid traffic black holes for Envoy.
- Centralize common `trafficPolicy` settings in a mesh- or namespace-wide policy if possible.
- Limit per-subset overrides unless necessary to keep configs maintainable.

```yaml
# destinationrule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: default
spec:
  host: reviews # Target service within the mesh this rule applies to
  trafficPolicy: # Applies to all connections in reviews service (unless otherwise overwritten by subset policy)
    connectionPool: # Limits number of connections Envoy proxy will open upstream, preventing resource exhaustion
      tcp:
        maxConnections: 100 # A single Envoy sidecar opens up entire reviews service pool to 100
      http:
        http1MaxPendingRequests: 50 # Max queue of 50 requests for HTTP/1.1
        http2MaxRequests: 100 # Max concurrent requests for HTTP/2 traffic across all connections
        maxRequestsPerConnection: 2 # Limits number of sequential HZTTP requests sent over single TCP connection
    loadBalancer:
      simple: LEAST_REQUEST # Default LB algorithm for all traffic to reviews (v1, v2, etc) to Least Request
    outlierDetection: # Circuit breaking for removal of unhealthy pods
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50 # Max % of pods that can be ejected at any time
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer: # Explicitly sets LB algorithm of v2 subset (canary version) to Round Robin
        simple: ROUND_ROBIN
```

- Combine circuit breaking with client-side retries and timeouts so apps gracefully degrade instead of long hangs.

#### Retries and Timeouts

- Set shorter timeouts near the caller and slightly longer ones deeper in the stack to prevent tail-latency amplification.

```yaml
# retries-timeouts.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service
spec:
  hosts:
  - api-service
  http:
  - route:
    - destination:
        host: api-service
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure,refused-stream
```

#### Traffic Mirroring

The goal of **Traffic Mirroring** strategy is to test the performance and functionality of a service v2 without impacting actual users. A copy of the actual traffic of a specified percentage is sent to a different subset.
- Used for **non-functional testing**: Load, Error rates, Logging, Infrastructure scaling.

```yaml
# traffic-mirror.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-mirror
spec:
  hosts:
  - api-service
  http:
  - route: # This is the primary rule for traffic, 100% routed to v1
    - destination:
        host: api-service
        subset: v1
      weight: 100
    mirror: # A copy of the incoming requests is sent to the v2 subset.
      host: api-service
      subset: v2
    mirrorPercentage:
      value: 10.0 # 10% is copied or mirrored, for every 10 primary requests, one copy is sent to v2
```

## Gateways

### Ingress Gateway Configuration

This configuration defines the entire entry point and routing logic for external traffic entering Istio service mesh.
- It combines a secure HTTP listener with application-aware routing rules.
- The `Gateway` resource configures listening ports and protocols while the `VirtualService` defines routing logic for specific hosts/paths.
- Backend traffic is routed for all /api paths for example: `app.example.com/api/v1/users`

```yaml
# ingress-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: public-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*" # Applies to all domain names hitting the gateway on port 80
    tls:
      httpsRedirect: true # Forces all incoming HTTP traffic to redirect to the HTTPS listener (443)
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE # Defines simple TLS termination (decrypting traffic at the gateway)
      credentialName: example-com-tls
    hosts:
    - "*.example.com" # Accepts HTTPS traffic for the example.com domain and all its subdomains
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend
  namespace: default
spec:
  hosts:
  - "app.example.com"
  gateways:
  - istio-system/public-gateway
  http:
  - match:
    - uri:
        prefix: "/api"
    route: # Rule 1: API Traffic routing to backend
    - destination:
        host: backend
        port:
          number: 8080
  - route: # Rule 2: Fallback, all other traffic routed to frontend (Default)
    - destination:
        host: frontend
        port:
          number: 80
```

### Egress Gateway Configuration

Below is an Istio configuration resources designed to manage and secure egress traffic (outbound from the mesh) to external services, specifically `*.external-api.com`.
- The `ServiceEntry` registers external service `*.external-api.com` within Istio's internal service registry. Telling sidecars that this host *exists outside the mesh*.
- The `VirtualService` defines rules for routing traffic destined for `*.external-api.com`, handling both the redirection and final routing.

```yaml
# egress-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway # Dedicated Istio proxy to handle outbound for specified hosts
metadata:
  name: egress-gateway
  namespace: istio-system
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - "*.external-api.com"
    tls:
      mode: PASSTHROUGH # Gateway only passes raw encrypted TCP stream (including SNI header) without terminating TLS
---
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry # Register an external destination with Istio's service registry
metadata:
  name: external-api
spec:
  hosts: # FQDNs of external service
  - "*.external-api.com"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL # Critical: Marks as external to mesh
  resolution: DNS # Use standard DNS lookup to resolve host's IP address
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: external-api
spec:
  hosts:
  - "*.external-api.com"
  gateways:
  - mesh # mesh applies to traffic originating from app sidecars
  - istio-system/egress-gateway # Targets dedicated egress gateway configured above
  tls:
  - match: # Matches sidecar proxy traffic (gateway: mesh)
    - gateways:
      - mesh
      port: 443
      sniHosts: # Server Name Indication Hosts: Perform TLS routing based on hostname
      - "*.external-api.com"
    route: # Redirects sidecar traffic to the internal egress gateway service
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 443
  - match: # Rule 2: matches traffic from Egress Gateway proxy itself
    - gateways:
      - istio-system/egress-gateway
      port: 443
      sniHosts:
      - "*.external-api.com"
    route:
    - destination: # Final Route: Send traffic out of the cluster to actual external host
        host: "api.external-api.com"
        port:
          number: 443
      weight: 100
```

## Security

`AuthorizationPolicy`: Istio's mechanism for controlling access to services. They specify **who** can do **what** under **which conditions**.
- A `selector` defines the target, using kubernetes labels, while the `action` can be `ALLOW` or `DENY`, following a set of `rules` (`from` and `to`).
- **Default Security Posture** would be to deny all (`spec: {}`) as **Zero-Trust** practice, while explicitly allowing specific rules.

```yaml
# deny-all.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec: # With no explicit rules, there is a default deny state
  {}
```

```yaml
# allow-frontend.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend # Name for allowing frontend to hit apps with matching label: backend
  namespace: default
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/frontend"] # Frontend service account
    to:
    - operation: # Restrict allowed operations to HTTP methods GET and POST, on path /api/*
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

- Path-Based Authorization: Demonstrates granular control based on request URI.

```yaml
# path-auth.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: admin-access
  namespace: default
spec:
  selector:
    matchLabels:
      app: admin-panel
  action: ALLOW
  rules:
  - from: # Rule 1: Allow users in default NS with SA admin access to admin/* path from admin-panel apps
    - source:
        principals: ["cluster.local/ns/default/sa/admin"]
    to:
    - operation:
        paths: ["/admin/*"]
  - from: # Rule 2: Allow any request principal to get the /health endpoint
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        paths: ["/health"]
        methods: ["GET"]
```

### JWT Authentication

- For the `RequestAuthorization` CRD, Istio fetches the **JWKS (Json Web Key Set)** file, `https://auth.example.com/.well-known/jwks.json`,  to get the public key required to verify the JWT's signature.
- For the `AuthorizationPolicy`, `["*"]` means "allow the request if the identity (principal) from the JWT is non-empty/exists.

```yaml
# jwt-auth.yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication # Defines how to validate incoming JSON web tokens (JWTs)
metadata:
  name: jwt-auth
  namespace: default
spec:
  selector: # This RequestAuthentication resource applies to pods/services with label app: api
    matchLabels:
      app: api
  jwtRules:
  - issuer: "https://auth.example.com" # Expected Issuer (iss) claim in the JWT
    jwksUri: "https://auth.example.com/.well-known/jwks.json" # URI for JSON web key set JWKS file
    audiences: # Expected Audience (aud) claim in the JWT
    - "api.example.com"
    forwardOriginalToken: true # If true, original JWT forwarded to app, if false (default), JWT is removed by sidecar after validation
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy # CRD for access control rules (permissions)
metadata:
  name: require-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: api
  action: ALLOW # Action to take if rules are met
  rules: # List of rules that must be satisfied to trigger ALLOW action
  - from:
    - source:
        requestPrincipals: ["*"]
```

### Network Policies

Below are 2 **Kubernetes Network Policies**, the 1st to Deny All Ingress, and the 2nd to Allow Specific Ingress.

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: default
spec:
  podSelector: {} # Empty selector matches every pod
  policyTypes: # Default action is to deny all ingress
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: default
spec:
  podSelector:
    matchLabels: # Targets only pods that are part of the backend service
      app: backend
  policyTypes: # Policy only concerns Ingress to the backend pods
  - Ingress # Defines the ALLOW rules for incoming traffic
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP # Allows frontend pods to connect to backend pods on TCP 8080
      port: 8080
```

### Security Best Practice

Below manifests are part of a production environment with isolation, mTLS, default authorization denial, and resource limiting.

```yaml
# security-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all-default # ZERO-TRUST, empty spec {} means deny ALL ingress to ALL services
  namespace: production
spec:
  {}
---
apiVersion: v1
kind: LimitRange # Denial of Service prevention by setting max resource limits a container can use/request
metadata:
  name: resource-limits
  namespace: production
spec:
  limits:
  - max:
      cpu: "2"
      memory: 2Gi
    min:
      cpu: 100m
      memory: 128Mi
    type: Container # Applied to all containers in the namespace
```


## Observability Integrations


### Prometheus Integration


### AWS CloudWatch Integration


## Performance Tuning (Large Clusters)

### Istiod Scaling

```yaml
# istiod-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: istiod
  namespace: istio-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: istiod
  minReplicas: 5
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 1
        periodSeconds: 120
```

### Sidecar Resource Optimization

```yaml
# sidecar-resources.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  values: |
    global:
      proxy:
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        concurrency: 2
```

### Sidecar Scoping

```yaml
# sidecar-scope.yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

### DNS Optimization

```yaml
# dns-optimization.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

## Best Practices

### Kubernetes Leases

Istiod is responsible for generating and pushing configuration (service discovery, traffic rules, security policies) to the sidecar proxies. 
- Some tasks must be performed by only one instance to prevent conflicts or unnecessary overhead.
- The Lease mechanism ensures that only one Istiod instance is the leader at any given time, providing stability and HA.

```yaml
# config/istio/leader-election.yaml
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: istio-leader
  namespace: istio-system
spec:
  holderIdentity: "istiod-0"
  leaseDurationSeconds: 30
  renewTime: "2024-01-01T00:00:00Z"
  leaseTransitions: 1
---
# Istio Deployment with Leader Election
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: istiod
      istio: pilot
  template:
    metadata:
      labels:
        app: istiod
        istio: pilot
    spec:
      serviceAccountName: istiod
      containers:
      - name: discovery
        image: auto
        args:
        - "discovery"
        - --monitoringAddr=:15014
        - --log_output_level=default:info
        - --domain
        - cluster.local
        - --keepaliveMaxServerConnectionAge
        - "30m"
        - --leader-election
        - --leader-election-lease-duration=30s
        - --leader-election-renew-deadline=15s
        - --leader-election-retry-period=5s
        env:
        - name: PILOT_ENABLE_LEADER_ELECTION
          value: "true"
        - name: LEADER_ELECTION_NAMESPACE
          value: istio-system
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 30
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /live
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 30
```
