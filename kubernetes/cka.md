# Kubernetes CKA

## Storage

- Create and manage `pv` and `pvc` resources, and understand the lifecylces.

- Create a `StorageClass`, Understand how StorageClasses automate persistent volumes.

- Mounting Volumes to pods, understand different volume types (e.g. `hostPath`, `emptyDir`)

## Troubleshooting

- General troubleshooting: (`kubectl describe`, `kubectl logs`, `kubectl exec`, `journalctl` to inspect `kubelet`)

- `CrashLoopBackOff` or `Pending` status debugging. `Liveness` and `Readiness` Probe debugging.

- Troubleshoot cluster components like `kube-apiserver` or control plane.
    - Scenario: A control plane component, kube-apiserver, is not running correctly and you cannot connect to the cluster.
        - Actions:
            - Cluster unreachable with kubectl, so SSH into the control plane node. `ssh control-plane-ip`
            - Check the static pod manifests at `/etc/kubernetes/manifests` and look for `kube-apiserver.yaml`
            - `cat kube-apiserver.yaml` and look for typos, broken volume refs, command args, image, etc. Changes will be picked up by kubelet.
            - Check Journalctl logs `journalctl -u kubelet --since "30 minutes ago"` and look for failed, invalid mount, image pull failed.
            - Inspect container logs: `crictl ps -a` or `crictl ps | grep kube-apiserver`, `docker ps -a`


- Diagnose a failed worker node.

- Troubleshoot service to service communication.

- Troubleshoot PVC stuck in Pending status.

## Workloads and Scheduling

- Create, manage, delete pods. Understand lifecycle and status

- Create and manage deployments, rollbacks, rolling updates (`kubectl rollout history`, `kubectl rollout undo`)
    - Scenario: a deployment web-app was updated and is in CrashLoopBackOff. Revert to previous stable version.
    - Actions:
        - `kubectl rollout history deployment/web-app` and find the correct revision.
        - `kubectl rollout undo deployment/web-app --to-revision=<rev-number>`

- Understand ReplicaSets, Creating and managing Statefulsets.

- Creating one-off `job` resources. Schedule recurring tasks with `CronJob`

- Apply `taints` to nodes to repel pods. Define `tolerations` on pods to allow them on tainted nodes.
    - Scenario: Ensure workload abc-pod is running only on certain nodes.
        - Actions:
            - Taint node1 with `kubectl taint nodes node1 key=abc-workload:NoSchedule`
            - Add a `tolerations` field in the manifest of abc-pod

            ```yaml
            spec:
              containers:
              - name: abc-container
                image: nginx
              tolerations:
              - key: "abc-workload"
                operator: "Equal"
                value: "NoSchedule"
                effect: "NoSchedule"
            ```


- Using `nodeSelector` to schedule pods on specific nodes. Use `affinity` and `anti-affinity` rules for complex scheduling.

## Cluster Architecture, Installation & Configuration

- Use `kubeadm` to bootstrap a cluster.
    - Scenario: Upgrade cluster from v1.32 to v1.33 using kubeadm.
    - Actions:
        - Upgrade the Control plane/master nodes: `kubeadm upgrade plan`, `kubeadm upgrade apply`.
        - Upgrade worker nodes one by one, `kubectl drain node1`, `kubeadm upgrade node1`, `kubectl uncordon node1`.

- Install a Pod network add-on (e.g. Calico, Flannel)

- HA Clusters (Concept of multiple control plane nodes, install manually)

- Certificate Management: TLS certs in K8 and `kubeadm certs check expiration`

- `etcd` backup and restore of the etcd database. Using `etcdtl`
    - Scenario: Cluster is down and we need to restore from etcd snapshot of healthy state.
    - Action:
        - `ETCDCTL_API=3 etcdctl snapshot save --endpoints=<etcd-endpoint-ip:2379> --cacert=ca-path ==cert=server-crt --key=key-path ./some-snapshot-path` to backup.
            - path is usually `/etc/kubernetes/pki/etcd/`
        - `etcdctl snapshot restore path-to-snapshot --data-dir=new-restored-dir`

- Prepare a node for maintanence using `kubectl drain node1 --ignore-daemonsets` and then `kubectl uncordon node1`

- Understand the roles of `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `kubelet`, `kube-proxy`, `etcd`.

## Services and Networking

- Service types: `ClusterIP`, `NodePort`, `LoadBalancer` and when to use each type.
    - Scenario: A new application needs to be accessible outside the cluster.
    - Actions:
        - Create the deployment.yaml or deployment with `kubectl create deployment deployment1 --image=nginx`
        - Expose the service `kubectl expose deployment.yaml --protocol=TCP --target-port=8080 --type=NodePort --name app1-service` (ports: at same level as selector)

- Understand how pods communicate and the role of `kube-proxy` and IP tables/IPVS rules.

- Understand the Ingress controller, and `Ingress` resources exposing services via HTTP/HTTPS.
    - Scenario: Create a NetworkPolicy in a dev1 namespace that denies all ingress to pods with label app=backend.
    - Actions:
        - Create a `NetworkPolicy` kind manifest.
        ```yaml
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: deny-all-ingress-backend
          namespace: dev
        spec:
          podSelector:
            matchLabels:
            app: backend
          policyTypes:
          - Ingress
          ingress: []  # <--- This means "deny all ingress"
        ```

- Troubleshoot DNS within the cluster, Understand role of `CoreDNS`.
    - Scenario: A pod in staging namespace cannot resolve service db-service in same namespace.
    - Actions:
        - Create a debug pod `kubectl run debug-pod --restart=Never --image=infoblox/dnstools --command -- sleep 3600`
        - Exec into the pod `kubectl exec -it debug-pod -- sh`
        - Test DNS resolution: `curl http://db-service.staging.svc.cluster.local`

## Exam Tips

- Use an **alias**: `alias k='kubectl'`

- Quickly generate a **yaml manifest**: `kubectl create <resource> <name> --dry-run=client -o yaml > file.yaml`
    - Simulate a request on the client side only, without sending to API server with `--dry-run=client`
    - Works with any resource type: configmap, secret, etc.

- Quickly run a **debugging pod** for 1 hour: `kubectl run debug-pod --restart=Never --image=busybox --command -- sleep 3600`

- Practice navigating the Kubernetes official [documentation](https://kubernetes.io/docs/home/).