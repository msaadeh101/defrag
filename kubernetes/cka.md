# Kubernetes CKA

## Storage

- Create and manage `pv` and `pvc` resources, and understand the lifecylces.

- Create a `StorageClass`, Understand how StorageClasses automate persistent volumes.

- Mounting Volumes to pods, understand different volume types (e.g. `hostPath`, `emptyDir`)

## Troubleshooting

- General troubleshooting: (`kubectl describe`, `kubectl logs`, `kubectl exec`, `journalctl` to inspect `kubelet`)

- `CrashLoopBackOff` or `Pending` status debugging. `Liveness` and `Readiness` Probe debugging.

- Troubleshoot cluster components like `kube-apiserver`.

- Diagnose a failed worker node.

- Troubleshoot service to service communication.

- Troubleshoot PVC stuck in Pending status.

## Workloads and Scheduling

- Create, manage, delete pods. Understand lifecycle and status

- Create and manage deployments, rollbacks, rolling updates (`kubectl rollout history`, `kubectl rollout undo`)

- Understand ReplicaSets, Creating and managing Statefulsets.

- Creating one-off `job` resources. Schedule recurring tasks with `CronJob`

- Apply `taints` to nodes to repel pods. Define `tolerations` on pods to allow them on tainted nodes.

- Using `nodeSelector` to schedule pods on specific nodes. Use `affinity` and `anti-affinity` rules for complex scheduling.

## Cluster Architecture, Installation & Configuration

- Use `kubeadm` to bootstrap a cluster.

- Install a Pod network add-on (e.g. Calico, Flannel)

- HA Clusters (Concept of multiple control plane nodes, install manually)

- Certificate Management: TLS certs in K8 and `kubeadm certs check expiration`)

- `etcd` backup and restore of the etcd database. Using `etcdtl`

- Upgrade cluster using `kubeadm` both control plane and worker nodes.

- Understand the roles of `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `kubelet`, `kube-proxy`, `etcd`.

## Services and Networking

- Service types: `ClusterIP`, `NodePort`, `LoadBalancer` and when to use each type.

- Understand how pods communicate and the role of `kube-proxy` and IP tables/IPVS rules.

- Understand the Ingress controller, and `Ingress` resources exposing services via HTTP/HTTPS.

- Troubleshoot DNS within the cluster, Understand role of `CoreDNS`.

## Exam Tips

- Use an **alias**: `alias k='kubectl'`

- Quickly generate a **yaml manifest**: `kubectl create <resource> <name> --dry-run=client -o yaml > file.yaml`
    - Simulate a request on the client side only, without sending to API server with `--dry-run=client`
    - Works with any resource type: configmap, secret, etc.

- Quickly run a **debugging pod** for 1 hour: `kubectl run d-pd --restart=Never --image=busybox --command -- sleep 3600`

- Practice navigating the Kubernetes official [documentation](https://kubernetes.io/docs/home/).