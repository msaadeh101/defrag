# Kubernetes

## Overview

### Node Components 
- `kubelet`: is an agent that runs on each node of the cluster. It works in terms of a *PodSpec* yaml that describes a pod.
- a `container runtime` like containerd needs to be installed on each node so pods can run. Needs to conform to CRI (Container Runtime Interface).
- `kube-proxy`: is the K8s network proxy that runs on each node, it does TCP forwarding to backend services.

### Control Plane Components
- `API Server`: main entrypoint for communication between nodes and control plane. It exposes the K8s api.
- `Scheduler`: responsible for assigning pods to nodes based on resource availability and requirements of pods.
- `Controller manager`: runs various controllers that monitor and manage the state of the cluster. i.e. Replication controller ensures desired number of pods for a given deployment.
- `etcd`: distributed key-value store to store the configuration and state of the cluster. Used by API server and other control plane components to store and retrieve cluster info.

### Kubernetes Objects

#### Workload

- `Pod`: Smallest deployable unit in K8, representing one or more containers that share storage, network, and lifecycle.
- `ReplicaSet`: Ensures specified number of identical Pods are always running, automatically replacing failed ones.
- `ReplicationController`: Legacy, older version of ReplicaSet.
- `Deployment`: Manages stateless applications by handling updates, rollbacks, and **scaling of ReplicaSets**.
  - `strategy`: 
    - `RollingUpdate`: Default, can define maxUnavailable, maxSurge
    - `Recreate`: Deletes all existing Pods before creating new ones, causes downtime.
  - `replicas`:
- `StatefulSet`: Manages stateful applications by assigning persistent identities and stable storage to Pods, **used for databases and queues**. Pods get a sticky identity (pod-0). Rollout behavior is ordered.
  - `updateStrategy`:
    - `RollingUpdate`: Updates pods one at a time, in reverse ordinal order (pod-2, pod-1, pod-0). Can pause updates using `partition`
    - `OnDelete`: Does not update automatically, must manually delete pods.
- `DaemonSet`: Ensures a Pod runs on every (or every selected) Node in the cluster - used for logging, monitoring or network agents.
- `Job`: Runs one or more Pods to completion for short-lived batch tasks, ensuring they finish successfully.
  - `restartPolicy`: Controls how individual pods are restarted by kubelet. `Never` (Default), `OnFailure`.
  - `backoffLimit`: How many times to retry failed pod in job.
  - `parallelism`: How many pods can run at same time for a job.
  - `completions`: How many successful Pods are required to consider Job complete.
  - `activeDeadlineSeconds`: Maximum time job is allowed to run, regardless of success/failure.
- `CronJob`: Schedules and runs Jobs on recurring time-based schedule, like UNIX **cron**.
  - `schedule`: When and how often the Job should run.
  - `jobTemplate`: the actual Job spec that gets created for each cronjob run.
  - `startingDeadlineSeconds`: Max time in seconds after scheduled time that job can start. Prevents stale execution.
  - `successfulJobHistoryLimit`: How many completed Jobs to keep.
  - `failedJobsHistoryLimit`: How many failed Jobs to retain for troubleshooting.
  - `concurrencyPolicy`: Whether multiple overlapping jobs are allowed. `Allow`, `Forbid`, `Replace`

#### Networking

- `Service`: Abstracts access to set of Pods, providing stable IP/DNS name to expose within or outside cluster. Internal Load balancer across replicas.
  - `ClusterIP`: Default. Internal to cluster. Internal load balancing via kube-proxy.
  - `NodePort`: Listens on each node in cluster. External access via nodePort: 30xxx
  - `LoadBalancer`: Provisions external load balancer.
- `Ingress`: Manages external HTTPS access using configurable route rules.
  - Options include: `Ingress-Nginx`, `HAProxy`, `Kong`, `Istio`, `Traefik`
  - `rules`: contains http paths, specifying a backend service with ports
- `HTTPRoute`: Part of the Gateway API. Replaces Ingress with more advanced routing, like header/path/method matching and reusable `Gateway` infra.
  - Used with `GatewayClass` and `Gateway` objects to define HTTP routing logic.
- `IngressClass`: Defines which controller to implement a given ingress. Can be many ingress controllers in a cluster.
- `Endpoint`: Represents IP addresses and ports for pods backing a Service.
- `EndpointSlice`: Scalable alternative to Endpoint object, breaking endpoints into multiple smaller chunks.
- `NetworkPolicy`: Defines rules to control traffic between Pods and or namespaces for secure communication within the cluster.
- `CNI Container Network Interface`: A Plugin system external to K8s to configure network interfaces for Pods, enabling IP assignment, routing, and network policy enforcement. Clouds have their own or you can use **Calico, Flannel, Weave Net, Cilium**.

#### Configuration and Storage

- `ConfigMap`: Stores non-sensitive key-value pairs injected into pods as env variables or mounted as files.
  - `data`: Can be Key: Value or conf.yml: | syntax
- `Secret`: Stores sensitive passwords, tokens and keys in base64 encoded format and injects securely into pods.
  - `Opaque`: Default, generic key-value pairs.
  - `kubernetes.io/dockerconfigjson`: Used for private docker registries. Data key is a `.dockerconfigjson`
  - `kubernetes.io/basic-auth`: Data keys are `username` and `password`
  - `kubernetes.io/tls`: Data keys are `tls.crt` and `tls.key`
  - `kubernetes.io/service-account-token`: Auto-generated token that allows access to API server. Used to mount tokens to pods.
- `PersistentVolume`: Represents piece of storage in the cluster provisioned by an admin or dynamically with a storage class.
- `PersistentVolumeClaim`: A user's request for storage that consumes a PV, with specific size and access requirements.
  - `accessModes` include `ReadWriteOnce` (single node, single app block storage), `ReadOnlyMany` (many nodes shared config), `ReadWriteMany` (many nodes, storage across replicas)
  - `reclaimPolicy`: `Retain` or `Delete`
- `StorageClass`: Defines a storage type (SSD, HDD, network-attached) and how volumes should be provisioned dynamically.
- `VolumeAttachment`: Tracks the attachment of a volume to a specific node, used with CSI drivers mainly to ensure volumes are attached before use.
- `CSIDriver`: Provides metadata and configuration for **Container Storage Interface CSI** driver installed in the cluster.
- `CSINode`: Describes which CSI drivers are installed/avaiable on a specific node.

#### Access and Security

- `ServiceAccount`: provides an identity for Pods to interact with the K8 API or external services, **often used with RBAC and tokens**.
- `Role`: Defines a set of permissions (like read/write) to K8 resources **within a specific namespace**.
- `ClusterRole`: Applies cluster-wide across all namespaces and non-namespaced resources (nodes).
- `RoleBinding`: Grants a Role to a user, group, or service account within a namespace.
- `ClusterRoleBinding`: Grants a ClusterRole to user, group or service account across entire cluster.

#### Cluster Level Resources

- `Node`: Represents worker machine in the cluster where pods are shceduled and run.
- `Namespace`: Divide cluster resources logically between teams or users within isolated environments.
- `LimitRange`: Defines default, min/max CPU and Memory limits for Pods and containers in a namespace.
- `ResourceQuota`: Enforces limits on the compute or object resources (pods, PVCs) that can be used in a namespace.
- `Event`: Records state changes, warnings, errors that occur in the cluster, used for debugging and auditing.
- `Lease`: Lightweight coordination resource used for leader election or heartbeat signaling in distributed controllers.
- `Binding`: A lower-level object that tells scheduler to bind a pod to a specific node.

#### Autoscaling

- `HorizontalPodAutoscaler`: Automatically scalles the number of Pod replicas in a Deployment, StatefulSet, or ReplicaSet based on CPU/Memory or custom metrics.
- `VerticalPodAutoscaler`: Automatically adjusts CPU and memory **requests/limits** for individual Pods based on actual usage. VPA via addon/controller

#### Scheduling

- `Affinity`, `NodeAffinity`, `PodAffinity`, `PodAntiAffinity`: Define rules to influence which nodes a Pod can be scheduled on based on labels or other relationships.
- `Taint`: On a node, prevents a pod from being scheduled unless they tolerate the taint.
- `Toleration`: Allows Pods to be scheduled on Nodes with matching taints (otherwise would repel them).
- `PriorityClass`: Assigns a priority value to Pods, influencing scheduling order and eviction preference when resources are scarce.
- `PodPreset`: Deprecated. Auto inject env variables, volumes, etc based on labels.

#### Policy and Admission

- `PodDisruptionBudget`: PDB, ensures minimum number of available Pods during voluntary disruptions like node drains or rolling updates.
- `PodSecurityPolicy`: Deprecated.
- `RuntimeClass`: Specifies which runtime and configuration to use for a Pod, enabling support for features like gVisor and Kata.
- `PriorityClass`: Determines eviction order during resource pressure. Also used in Scheduling.
- `ValidatingWebhookConfiguration`: Registers webhooks that can validate objects before they are persisted in the cluster.
- `MutatingWebhookConfiguration`: Registers webhooks that can modify objects during admission, often used to inject sidecars or apply default values.

#### Custom Resources and Extensions

- `CustomResourceDefinition`: CRD, extens K8 API by derfining own resource types and enabling kubectl to manage them.
- `APIService`: Registers an external or aggregated API server with the K8 API server, enabling extension of Kubernetes with entirely separate APIs. Like MetricsServer.

#### Internal System Types

- `ControllerRevision`
- `TokenReview`
- `SubjectAccessReview`
- `SelfSubjectAccessReview`
- `SelfSubjectRulesReview`
- `RuntimeClass`
- `FlowSchema`
- `PriorityLevelConfiguration`

#### Extensions

- `Route`: Openshift
- `VirtualService`, `DestinationRule`: Istio
- `Application`: ArgoCD

### Other Basics

- Service Discovery `my-service.my-namespace.svc.cluster.local` to access services. (Where cluster.local is the default cluster DNS domain).
- Docker builds images using the `Open Container Initiative (OCI)` image format, which is platform agnostic.
- K8s has a "hub-and-spoke" API pattern.
- Nodes should be provisioned with the public root cert for the cluster so they can connect to the API server.
- `Role` and `ClusterRole` define permissions in kubernetes, but to a single namespace, and cluster-wide resources respectfully.
- A `controller` tracks at least one K8s resource type and keeps it to the desired state.
- Use `VPA` (Vertical Pod Autoscaler) to adjust the resource requests/limits of pods before adjusting replicas with `HPA` (Horizontal Pod Autoscaler).
  - VPA forces downtime, because the pods need to be deleted and recreated
- Use `kubectl describe` or `kubectl get events` to collect event data about the Cluster/Pods, etc.
- Consider carefully if and how to set your `pod disruption budget (pdb)`. Recommendations vary on if its a stateless/single-instance stateful, multi-instance stateful, batch job, etc.
- Pods can have `init` containers and `sidecar` containers.
  - Init containers must run berfore the main app starts to perform one-time startup tasks.
  - Sidecar containers run alongside the main app for supporting features like logging, monitoring, proxying (istio), and file syncing.

### Kubernetes Network Model

- Each `pod` in a cluster gets its own unique cluster-wide IP address.
- The `pod network` aka the *cluster network* handles communication between pods.
    - Ensures all pods can communicate with other pods. Pods can communicate directly or via proxies, NAT.
    - Ensures that node agents like system daemons or kubelet can communicate with all pods on that node.
- The `Service API` lets you provide long-lived IP or hostname for a service implemented by 1+ backend pods. But the individual pods making up the service can change over time.
    - Kubernetes provides information about pods currently backing a Service. Managed by `EndpointSlice` objects.
- The `Gateway API` aka `Ingress` allows you to make services accessible to clients OUTSIDE the cluster.
    - Service API `type: LoadBalancer` is a simpler, less configurable mechanism for cluster ingress.
- `Network Policy` is a built-in K8s API that allows you to control traffic between pods, or between pods and the outside.

- On Linux, most container runtimes use the `Container Networking Interface (CNI)` to interact with the pod network implementation. These implementations are called *CNI Plugins*

- `kube-proxy` is the default implementation of service proxying, but some pod network implementations use their own service proxy.

### Container Images Best Practices

- Use minimal OS for your containers as with fewer packages there is less attack surface.
- Minimize image layers to improve portability and security.
- Automate host and OS and package patches. Use a container scanning tool like Aqua or Prisma or Snyk.

### Kubectl Cheat Sheet
```bash
# Check IAM permissions of cluster (EKS)
kubectl auth can-i list nodes
kubectl auth can-i list deployments --all-namespaces
kubectl auth can-i list secrets --all-namespaces

# Exec into a pod and execute command
kubectl exec my_pod -n default -- /bin/bash -c "echo hello"

# Access the K8s API server
kubectl proxy

# exec into pod and open interactive terminal
kubectl exec -n my_pod -n default -- /bin/bash

# port forward POD LOCAL_MACHINE_PORT:REMOTE_POD_PORT
kubectl port-forward nginx-sadfs333 8080:80
# above is now accessible at http://localhost:8080

# Watch Kuberentes events in realtime (w)
kubectl get events -w --sort-by '.lastTimestamp'

# Copy files <source> <destination> -c containername # if multi-container
kubectl cp my-pod-asdhn34324:/usr/share/location/file.txt ~/user/desktop/my-file.txt

# set new size for deployment/replica set/stateful set, etc
# scale replicaset named foo to 3
kubectl scale --replicas=3 rs/foo
```

### K8s Troubleshooting

#### ImagePullBackOff / ErrImagePull
- `imagepullbackoff` or `errImagePull`, and are some of the most common pod failures.
- `errorImagePull` is the initial error, and the subsequent error after several failures is `ImagePullBackOff`
- Networking: maybe registry URL unreachable, firewall configuration, proxy settings. Validate with `curl` or `wget` from inside the network.
- Authorization: Check `imagePullSecrets` are set up correctly if needed. 
- Check validity of image name or tags
- Insufficent storage or disk space. Check the node health via UI or `df -h` to check capacity on node. Maybe the image is too large?
- Ensure your service account has the correct permissions to pull the image. Check the role/role binding with `kubectl get role my-role -n default` and `kubectl get rolebinding my-rolebinding -n default`
- 3rd party image registry issues

#### CrashLoopBackOff

- Happens when an app inside a pod crashes repeatedly, and kubelet attempts to restart it unsuccessfully.
- Check the status with `kubectl describe pod podname` to confirm the exit code, reason, any other error messages.
- Could be Bugs within the app that you can check with `kubectl logs podname`.
- Insufficient memory or cpu which you can check with `kubectl top pod`
- Missing or misconfigured environment variables/configmap.
- Could be port conflicts if multiple apps attempt to bind to the same port within the pod.

#### 503 Error
- Service has no healthy pods to route traffic to.
- Check the Ingress or LoadBalancer is configured correctly.
- Possibly the application isn't responding inside the pod. Check with `kubectl port-forward` and check your localhost directly.
  - If there is still a 503, then its not as network issue most likely and is an app misconfiguration.
  - If it works via port-forwarding but not the service, check the endpoints with `kubectl get endpoints`

#### Memory/CPU Issues

- Check pod usage with `kubectl top` command.
- Use separate VPA and HPA definitions for autoscaling.
- VPA adjusts the CPU/memory requests for pods instead of changing number of replicas
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
```

- HPA scales replicas when memory or CPU reach a target utilization.
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"  # VPA will automatically update pod resources
  resourcePolicy:
    containerPolicies:
      - containerName: "*"  # Apply to all containers in the pod
        minAllowed:
          cpu: "200m"
          memory: "256Mi"
        maxAllowed:
          cpu: "2"         # Equivalent to 2 cores
          memory: "2Gi"
```

#### Pod Pending
- Could be that no available nodes that match the node-selectors,taints and tolerations exist.
- Cluster could be taking time to scale nodes.
- Could be waiting on a PVC to become bound. Use `kubectl get pvc` and if any are stuck in Pending, then check the StorageClass

#### Liveness/Readiness Probe Failures
- If you `kubectl describe my-app` and you get "Liveness Probe failed" or "Readiness Probe Failed"
- Double Check the `initialDelaySeconds`, it could not allow enough time for the app to start.
- Check the endpoint of the probes to make sure the `path` and `port` are correct.

## AWS EKS

### Security

- Key IAM Role Types in EKS

| IAM Role Type | Purpose |
| --------- | ----------- |
|EKS Cluster IAM Role| Allows EKS to interact with AWS services.|
|Node IAM Role| Grants worker nodes permissions to pull container images, write logs, etc.|
|IAM Roles for Service Accounts(IRSA) | Assigns fine-grained IAM permissions to specific pods|

- DO NOT touch the `aws-auth` configmap in managed clusters.

#### AWS Secrets Manager in EKS:

- [Documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/ascp-eks-installation.html)

- ASCP with Pod Identity method enhacnes security and simplifies configuration for accessing secrets in EKS. 
- Granular permissions at the pod level.
- Available as Secrets Store CSI Driver (Helm Chart as well).

- To programmatically connect to Secrets Manager, use an `endpoint` which is the URL.
- Can perform AWS managed rotation or rotation by Lambda function.



### EKS Networking Basics

- EKS uses the Amazon VPC CNI Plugin to assign Elastic Network Interfaces (ENIs) and private IPs from the VPC to pods.
- Each worker node gets an ENI with multiple secondary IPs (assigned to pods).
- Pods can communicate across AZs and AWS services via VPC.
- When a pod on Node A communicates with Node B, it uses VPC networking instead of an overlay like Calico.

#### Service Networking

- Types of Services in EKS

|Service Type | Use Case |
| ------------ | ------------ |
| ClusterIP | Default service type, allows internal communication between pods. |
|NodePort | Exposes a service on each node's IP at a static port. |
| LoadBalancer | Creates an AWS ELS (ALB or NLB) to expose services externally |
| Headless Service | Directly routes traffic to pods (for dbs, etc.) |

- Example LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

#### Ingress

To expose multiple services with one external IP, use Ingress with AWS Application Load Balancer (ALB).

1. User accesses https://my-app.com/api
2. AWS ALB routes traffic to correct K8s service based on URL path
3. Service sends traffic to correct pod

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

#### Egress

- By default, pods can access internet via worker nodes Network Address Translation (NAT) Gateway or Internet Gateway.
- **For Private Clusters** you must configure NAT GW or AWS PrivateLink.

- Restrict Egress using NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress: []
```

#### Types of AWS Load Balancers

- `ALB`: Application Load Balancer, routes HTTP(S) traffic to services using ingress.
- `NLB`: Network Load Balancer, exposes services using `LoadBalancer` type for high-performance TCP traffic.
- `CLB`: Classic Load Balancer, legacy, *DO NOT USE*