# Couchbase for DevOps: Complete Guide & Tips

## Table of Contents
- [1. Introduction](#1-introduction)
- [2. Installation & Setup](#2-installation--setup)
- [3. Cluster Management](#3-cluster-management)
- [4. Performance Optimization](#4-performance-optimization)
- [5. Security Best Practices](#5-security-best-practices)
- [6. Backup & Disaster Recovery](#6-backup--disaster-recovery)
- [7. Couchbase Automation (Terraform, Ansible, Kubernetes)](#7-couchbase-automation-terraform-ansible-kubernetes)
- [8. Tips & Tricks](#8-tips--tricks)

---

## 1. Introduction
Couchbase is a NoSQL, high-performance, distributed database designed for modern cloud-native applications. This guide focuses on **DevOps** best practices for managing Couchbase in production.

## 2. Installation & Setup
### **Install Couchbase on Linux**
#### **RHEL/CentOS:**
```sh
sudo yum install -y couchbase-server-enterprise-7.2.0.rpm
```
#### **Ubuntu/Debian:**
```sh
sudo dpkg -i couchbase-server-enterprise_7.2.0.deb
```
#### **Start Service:**
```sh
sudo systemctl enable couchbase-server
sudo systemctl start couchbase-server
```
#### **Verify Installation:**
```sh
curl -X GET http://localhost:8091/pools
```

## 3. Cluster Management
### **Create a Couchbase Cluster**
```sh
couchbase-cli cluster-init -c localhost --cluster-username Administrator --cluster-password password \
    --cluster-ramsize 4096 --services data,index,query
```
### **Add a Node to Cluster**
```sh
couchbase-cli server-add -c <cluster-ip>:8091 \
    --username Administrator --password password \
    --server-add <new-node-ip>:8091 --server-add-username Administrator \
    --server-add-password password
```
### **Rebalance Cluster**
```sh
couchbase-cli rebalance -c <cluster-ip>:8091 --username Administrator --password password
```


## 4. Performance Optimization
### **Monitor Cluster Performance**
```sh
cbstats localhost:11210 all | grep ep_queue_size
```
### **Optimize Indexing**
```sql
ALTER INDEX `primary` ON `test-bucket` WITH {"num_replica": 1};
```
### **Enable Auto-Compaction**
```sh
couchbase-cli setting-compaction -c localhost:8091 --username Administrator --password password \
    --view-fragmentation-threshold-percentage 30
```

## 5. Security Best Practices
### **Enable TLS for Secure Communication**
```sh
couchbase-cli ssl-manage -c localhost:8091 --username Administrator --password password --set-cert
```
### **Enable Role-Based Access Control (RBAC)**
```sh
couchbase-cli user-manage -c localhost:8091 --username Administrator --password password \
    --set --rbac-username readonly_user --rbac-password read123 \
    --roles ro_admin --auth-domain local
```
### **Enable Audit Logging**
```sh
couchbase-cli setting-audit -c localhost:8091 --username Administrator --password password --audit-enabled 1
```


## 6. Backup & Disaster Recovery
### **Backup Using `cbbackupmgr`**
```sh
mkdir -p /backups/couchbase
cbbackupmgr config --archive /backups/couchbase --repo test-repo
cbbackupmgr backup --archive /backups/couchbase --repo test-repo --cluster http://localhost:8091 --username Administrator --password password
```
### **Restore Backup**
```sh
cbbackupmgr restore --archive /backups/couchbase --repo test-repo --cluster http://localhost:8091 --username Administrator --password password
```

## 7. Couchbase Automation (Terraform, Ansible, Kubernetes)
### **Deploy Couchbase with Terraform**
```hcl
resource "couchbase_bucket" "my_bucket" {
  name         = "my_bucket"
  memory_quota = 512
  type         = "couchbase"
}
```
### **Automate with Ansible**
```yaml
- name: Install Couchbase
  hosts: couchbase_servers
  become: yes
  tasks:
    - name: Install Couchbase Server
      yum:
        name: couchbase-server
        state: present
```
### **Deploy on Kubernetes with Helm**
```sh
helm repo add couchbase https://couchbase-partners.github.io/helm-charts/
helm install my-couchbase couchbase/couchbase-operator
```

## 8. Tips & Tricks
### **1. Quickly Flush a Bucket (Dangerous in Production!)**
```sh
couchbase-cli bucket-edit -c localhost:8091 --username Administrator --password password \
    --bucket my-bucket --enable-flush 1
```
### **2. Enable Query Performance Logging**
```sh
couchbase-cli setting-query -c localhost:8091 --username Administrator --password password --log-level DEBUG
```
### **3. Monitor Bucket Statistics**
```sh
cbstats localhost:11210 all | grep kv_curr_items
```
### **4. Set Memory Quota Efficiently**
```sh
couchbase-cli setting-cluster -c localhost:8091 \
    --cluster-username Administrator --cluster-password password \
    --cluster-ramsize 4096 --cluster-index-ramsize 1024
```
### **5. Rotate Admin Passwords Periodically**
```sh
couchbase-cli setting-password-policy -c localhost:8091 --username Administrator --password password --min-length 12
```

## **Conclusion**
By following these best practices and automation techniques, you can **securely and efficiently manage Couchbase** in a **DevOps** environment.
