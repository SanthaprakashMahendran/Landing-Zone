# **Topic 15: Storage — PV, PVC, StorageClass & CSI ⭐ — Complete Notes**

> **Sandbox practicability:** ✅ Mostly.
> ✅ List StorageClasses, create PVCs, mount them in pods, prove persistence, expand a volume (if allowed).
> ⚠️ Storage quota may limit size and count. Snapshots depend on the cluster's CSI driver.
> ❌ Installing CSI drivers/operators, creating StorageClasses, ODF and EFS setup need admin.
> Your **Installed Operators** page already shows an **AWS EFS CSI Driver Operator** (see section 7).

---

## **Table of Contents**
1. Introduction
2. Storage Concepts Recap (PV, PVC, StorageClass)
3. CSI Drivers on OpenShift
4. StorageClasses on ROSA/AWS
5. Access Modes & Volume Modes
6. Using a PVC in Your App
7. EBS vs EFS vs ODF
8. Binding Modes & Availability Zones
9. Expanding Volumes
10. Snapshots & Backup
11. StatefulSets
12. Non-Persistent Volumes (emptyDir, ConfigMap, Secret)
13. Storage and SCC (Permissions)
14. Troubleshooting
15. Real-World Examples
16. Best Practices
17. Hands-on Lab (Sandbox)
18. Key Takeaways

---

## **1. Introduction**

Container filesystems are **temporary**. When a pod is replaced, its data is gone. For databases, uploads and shared files you need **persistent storage**.

```
Pod  ──mounts──▶  PVC  ──binds──▶  PV  ──backed by──▶  Disk (EBS, EFS, Ceph...)
                   ▲                                       ▲
         (what the app asks for)              (created by a StorageClass automatically)
```

If you know Kubernetes storage, **OpenShift is the same**, but with:
- **CSI drivers installed and managed through operators**
- **StorageClasses preconfigured** for the platform (gp3-csi on AWS)
- **SCC rules** that decide who can write to the volume (section 13)

---

## **2. Storage Concepts Recap (PV, PVC, StorageClass)**

| Object | Who creates it | Meaning |
|---|---|---|
| **StorageClass (sc)** | Admin | A "type" of storage (fast SSD, shared file, ...) and the driver that provisions it |
| **PersistentVolume (pv)** | Automatically (dynamic provisioning) | The actual volume |
| **PersistentVolumeClaim (pvc)** | **You** (project-level) | "I need 5Gi of storage class X" |

```bash
oc get sc                    # cluster-wide, readable
oc get pvc                   # in your project
oc get pv                    # cluster-wide (admin ❌), so you only see PVs via your PVCs
```

### **Dynamic provisioning flow**

```
1. You create a PVC (storageClassName: gp3-csi, 5Gi)
2. The CSI driver creates an EBS volume
3. A PV object is created and bound to your PVC
4. A pod that mounts the PVC gets the volume attached to its node
```

---

## **3. CSI Drivers on OpenShift**

**CSI (Container Storage Interface)** is the plugin standard for storage. Each storage backend has a CSI driver.

| Backend | Driver | Installed by |
|---|---|---|
| AWS EBS | `ebs.csi.aws.com` | **Default** on AWS/ROSA (cluster storage operator) |
| AWS EFS | `efs.csi.aws.com` | **AWS EFS CSI Driver Operator** (via OLM) |
| Azure Disk / File | `disk.csi.azure.com`, `file.csi.azure.com` | Default on Azure |
| GCP PD | `pd.csi.storage.gke.io` | Default on GCP |
| vSphere | `csi.vsphere.vmware.com` | Default on vSphere |
| Ceph (ODF) | `rbd.csi.ceph.com`, `cephfs.csi.ceph.com` | **OpenShift Data Foundation** |

```bash
oc get csidriver
oc get csinode               # admin-ish
oc get pods -n openshift-cluster-csi-drivers     # may be forbidden
```

In your screenshot the **AWS EFS CSI Driver Operator** shows `Succeeded`, but "installed" doesn't mean you can use it yet. An admin must still create the **EFS filesystem** and a **StorageClass** for it.

---

## **4. StorageClasses on ROSA/AWS**

```bash
oc get sc
```

Typical output:

```
NAME                PROVISIONER       RECLAIMPOLICY  VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
gp3-csi (default)   ebs.csi.aws.com   Delete         WaitForFirstConsumer   true
gp2-csi             ebs.csi.aws.com   Delete         WaitForFirstConsumer   true
```

| Field | Meaning |
|---|---|
| `(default)` | Used when a PVC doesn't name a class |
| `provisioner` | The CSI driver |
| `reclaimPolicy` | `Delete` removes the cloud disk when the PVC is deleted. `Retain` keeps it |
| `volumeBindingMode` | `WaitForFirstConsumer` waits until a pod is scheduled, so the disk is created in the **same AZ** |
| `allowVolumeExpansion` | Whether you can grow a PVC |

### **StorageClass YAML (admin)**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "4000"
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

---

## **5. Access Modes & Volume Modes**

### **Access modes**

| Mode | Short | Meaning | Typical backend |
|---|---|---|---|
| **ReadWriteOnce** | RWO | One **node** reads/writes | EBS (block) |
| **ReadWriteMany** | RWX | Many nodes read/write | EFS, CephFS, NFS |
| **ReadOnlyMany** | ROX | Many nodes read-only | EFS, CephFS |
| **ReadWriteOncePod** | RWOP | Exactly one **pod** | CSI drivers that support it |

> **EBS can't be RWX.** Several replicas on different nodes sharing one EBS volume doesn't work, so use EFS or ODF for shared files.

### **Volume modes**

| Mode | Meaning |
|---|---|
| `Filesystem` (default) | Mounted as a directory |
| `Block` | Raw device (databases, VMs) |

---

## **6. Using a PVC in Your App**

### **Create a PVC**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: landing-data
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  # storageClassName: gp3-csi     # omit to use the default
```

### **Mount it in the Deployment**

```yaml
spec:
  template:
    spec:
      containers:
        - name: landing-app
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: landing-data
```

### **Or with one command**

```bash
oc set volume deploy/landing-app --add --name=data \
   --type=pvc --claim-name=landing-data --claim-size=1Gi \
   --claim-mode=ReadWriteOnce --mount-path=/data
```

### **Prove persistence**

```bash
oc rsh deploy/landing-app
echo "hello $(date)" > /data/test.txt
exit
oc delete pod -l app=landing-app           # the pod is replaced
oc rsh deploy/landing-app cat /data/test.txt   # file survived
```

### **Deployment strategy caveat (RWO)**
With a **RWO** volume and `RollingUpdate`, the new pod may start on a **different node** while the old pod still holds the volume, giving a **Multi-Attach error**. Fix:

```yaml
strategy:
  type: Recreate          # stop the old pod first
```

(or use RWX storage, or a StatefulSet).

---

## **7. EBS vs EFS vs ODF**

| | **EBS (gp3-csi)** | **EFS** | **ODF (Ceph)** |
|---|---|---|---|
| Type | Block | Shared file (NFS) | Block, file and object |
| Access | RWO | **RWX** | RWO, **RWX** |
| AZ scope | **One AZ** | **Regional** (multi-AZ) | Cluster |
| Performance | High IOPS | Moderate, higher latency | High (depends on nodes) |
| Cost | Per GB provisioned | Per GB used + throughput | Extra nodes and licensing |
| Setup | ✅ Built in | Operator + EFS filesystem + StorageClass | ODF operator and dedicated nodes |
| Use for | Databases, single-writer apps | Shared uploads, CMS, shared config | Full storage platform, object (S3-like) |

### **Using EFS (admin steps, for reference)**

```
1. Create an EFS filesystem + mount targets in your VPC subnets (AWS)
2. IAM role for the EFS CSI driver (STS on ROSA)
3. Install "AWS EFS CSI Driver Operator" (OLM), you already have this
4. Create ClusterCSIDriver + a StorageClass:
```

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0123456789abcdef0
  directoryPerms: "700"
```

Then a PVC with `accessModes: [ReadWriteMany]` and `storageClassName: efs-sc` lets **many replicas on many nodes** share one volume.

---

## **8. Binding Modes & Availability Zones**

EBS volumes live in **one AZ**. A pod using it must run in **that AZ**.

| Mode | Behaviour |
|---|---|
| `Immediate` | The volume is created right away, in a random AZ, so the pod may be unschedulable if no node is in that AZ |
| **`WaitForFirstConsumer`** | The volume is created **after** the pod is scheduled, in the pod's AZ ✅ (default on AWS) |

### **Consequences**
- A PVC stays **`Pending`** until a pod uses it. That's normal with `WaitForFirstConsumer`.
- If the node dies, a replacement pod must start in the **same AZ**, so keep worker capacity in every AZ.
- For multi-AZ resilience of shared data, use **EFS/ODF** or **replicate at the application level** (database replicas).

---

## **9. Expanding Volumes**

Allowed when the StorageClass has `allowVolumeExpansion: true`.

```bash
oc patch pvc landing-data -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
oc get pvc landing-data -w          # status: FileSystemResizePending → Bound at 5Gi
```

- **Grow only.** You can't shrink.
- EBS expansion usually completes online (while the pod runs), and the filesystem grows after a short wait or a pod restart.
- Respect your **project storage quota** (Topic 13).

---

## **10. Snapshots & Backup**

### **CSI VolumeSnapshots**

```bash
oc get volumesnapshotclass
```

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: landing-data-snap1
spec:
  volumeSnapshotClassName: csi-aws-vsc
  source:
    persistentVolumeClaimName: landing-data
```

### **Restore into a new PVC**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: landing-data-restored
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  dataSource:
    name: landing-data-snap1
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### **Backups (cluster level)**
**OADP** (OpenShift API for Data Protection, Velero-based, an Operator) backs up **namespaces, objects and volumes** to S3. A snapshot is **not** a backup. Keep copies outside the cluster.

---

## **11. StatefulSets**

For databases and clustered apps that need **stable identity + their own volume per replica**:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
        - name: postgres
          image: quay.io/sclorg/postgresql-15-c9s:latest
          env:
            - { name: POSTGRESQL_USER,     value: app }
            - { name: POSTGRESQL_DATABASE, value: appdb }
            - name: POSTGRESQL_PASSWORD
              valueFrom: { secretKeyRef: { name: pg-secret, key: password } }
          ports:
            - containerPort: 5432
          volumeMounts:
            - { name: data, mountPath: /var/lib/pgsql/data }
  volumeClaimTemplates:
    - metadata: { name: data }
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests: { storage: 2Gi }
```

- Each replica gets its own PVC: `data-postgres-0`, `data-postgres-1`, ...
- Pods are named `postgres-0`, `postgres-1`; DNS `postgres-0.postgres`.
- Deleting the StatefulSet **does not delete the PVCs** (a safety feature).
- For production databases, prefer an **Operator** (Topic 7/8): it handles backups, failover and upgrades.

---

## **12. Non-Persistent Volumes (emptyDir, ConfigMap, Secret)**

| Volume | Lifetime | Use |
|---|---|---|
| **emptyDir** | The pod's life | Scratch space and caches. `medium: Memory` for tmpfs |
| **configMap** | Updates with the ConfigMap | Config files |
| **secret** | Updates with the Secret (tmpfs) | Certificates and keys |
| **projected** | Combination | Service account tokens and mixed sources |
| **downwardAPI** | | Pod metadata as files |

```yaml
volumes:
  - name: tmp
    emptyDir: {}
  - name: config
    configMap:
      name: landing-config
```

Under SCC the root filesystem is usually fine, but **only `/tmp` and mounted volumes are reliably writable** for random UIDs. Use an `emptyDir` when an app needs a writable cache directory.

---

## **13. Storage and SCC (Permissions)**

OpenShift runs pods with a **random UID** from the project's range (Topic 6). How can that user write to a volume?

### **fsGroup**

The `restricted` SCC sets an **fsGroup** (a supplemental group) from the project range, and Kubernetes makes the volume **group-writable** for that group.

```bash
oc get project santha-dev -o yaml | grep -A3 annotations
# openshift.io/sa.scc.uid-range: 1000760000/10000
# openshift.io/sa.scc.supplemental-groups: 1000760000/10000

oc rsh deploy/landing-app id
# uid=1000760000 gid=0 groups=0,1000760000
```

### **Common problems**

| Problem | Cause | Fix |
|---|---|---|
| `Permission denied` writing `/data` | Image expects a specific UID or root | Use an image built for OpenShift, or `chmod g+rwX` for GID 0 in the image |
| Existing data owned by another UID (NFS) | `fsGroup` can't change ownership on that backend | Set permissions on the NFS export, or use an SCC with the right `fsGroup` strategy (admin) |
| Postgres image fails to start as arbitrary UID | Official image needs a fixed UID | Use the **`sclorg`/Red Hat** images (they support arbitrary UIDs) |

---

## **14. Troubleshooting**

| Symptom | Check | Cause / fix |
|---|---|---|
| PVC **Pending** | `oc describe pvc` | `WaitForFirstConsumer` (normal until a pod uses it), or no matching StorageClass or no capacity |
| `exceeded quota ... requests.storage` | `oc describe quota` | Project storage quota (Topic 13) |
| Pod **Pending**: `volume node affinity conflict` | `oc describe pod` | The volume is in a different AZ than any schedulable node |
| `Multi-Attach error for volume` | `oc describe pod` | RWO volume still attached to another node. Use `Recreate` or RWX |
| `Permission denied` on the volume | `oc rsh pod id`, `ls -ld /data` | SCC UID/fsGroup (section 13) |
| PVC stuck **Terminating** | `oc describe pvc` | A pod is still using it. Delete the pod/Deployment first |
| Expansion stuck | `oc describe pvc` → conditions | StorageClass doesn't allow it, or a pod restart is needed |
| Data lost after `oc delete` | `reclaimPolicy: Delete` | Deleting the PVC deletes the disk. Use `Retain` or snapshots for important data |
| `no storage class` | `oc get sc` | No default class. Set `storageClassName` |

### **Debug order**

```bash
oc get pvc,pv
oc describe pvc <name>
oc describe pod <pod> | tail -25
oc get events --sort-by=.lastTimestamp | tail
oc get sc
```

---

## **15. Real-World Examples**

### **Example 1: Persistent upload folder for the web app**

```bash
oc set volume deploy/landing-app --add --name=uploads --type=pvc \
  --claim-name=uploads --claim-size=2Gi --mount-path=/data/uploads
oc patch deploy landing-app -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
```

### **Example 2: Shared storage for 3 replicas**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: shared-assets }
spec:
  accessModes: [ReadWriteMany]      # needs EFS/ODF/NFS-backed class
  storageClassName: efs-sc
  resources:
    requests: { storage: 5Gi }
```

### **Example 3: A database with a PVC (quick version)**

```bash
oc create secret generic pg-secret --from-literal=password=ChangeMe123
oc new-app quay.io/sclorg/postgresql-15-c9s:latest --name=postgres \
   -e POSTGRESQL_USER=app -e POSTGRESQL_DATABASE=appdb \
   -e POSTGRESQL_PASSWORD=ChangeMe123
oc set volume deploy/postgres --add --name=data --type=pvc \
   --claim-size=2Gi --mount-path=/var/lib/pgsql/data
oc rollout status deploy/postgres
oc rsh deploy/postgres psql -U app appdb -c '\l'
```

### **Example 4: Snapshot before a risky change**

```bash
oc apply -f volumesnapshot.yaml
oc get volumesnapshot
```

---

## **16. Best Practices**

- ✅ Use **dynamic provisioning** with a named **StorageClass**
- ✅ Choose by need: **RWO/EBS** for single-writer, **RWX/EFS or ODF** for shared data
- ✅ Use **`Recreate`** (or StatefulSets) for RWO volumes, to avoid Multi-Attach errors
- ✅ Use **`WaitForFirstConsumer`** on AWS and keep nodes in every AZ
- ✅ Use **Operators** for production databases (backups, failover)
- ✅ Take **VolumeSnapshots** *and* off-cluster **backups** (OADP)
- ✅ Use images built for **arbitrary UIDs** (OpenShift/Red Hat images)
- ✅ Set **`reclaimPolicy: Retain`** for critical data classes
- ❌ Don't store state in the container filesystem
- ❌ Don't confuse a snapshot with a backup
- ❌ Don't run databases on a RWX NFS share unless the vendor supports it

---

## **17. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted · ❌ admin only

| # | Task | Status |
|---|---|---|
| 1 | `oc get sc` and note the default class, binding mode and expansion setting | ✅ |
| 2 | Create PVC `landing-data` (1Gi) and observe it **Pending** (`WaitForFirstConsumer`) | ✅ |
| 3 | Mount it with `oc set volume ...`, then watch the PVC become **Bound** | ✅ |
| 4 | Write `/data/test.txt`, delete the pod, and confirm the file is still there | ✅ |
| 5 | Compare against a pod with **no** volume (write to `/tmp`, delete the pod, and see the file vanish) | ✅ |
| 6 | Scale to 2 replicas with a RWO PVC and watch for Multi-Attach or same-node scheduling. Switch to `Recreate` | ✅ |
| 7 | `oc rsh deploy/landing-app id` and `ls -ld /data` (UID/fsGroup in action) | ✅ |
| 8 | Expand the PVC from 1Gi to 2Gi | ⚠️ (needs `allowVolumeExpansion` and quota) |
| 9 | Deploy Postgres with a PVC (Example 3) and confirm data survives a pod restart | ✅ |
| 10 | Create a VolumeSnapshot | ⚠️ (needs a VolumeSnapshotClass) |
| 11 | Use the EFS StorageClass for RWX | ❌ (admin must create it) |

### **Expected learning outcomes**
- You can request storage and prove it persists.
- You can explain RWO vs RWX and why EBS is AZ-bound.
- You understand how SCC fsGroup lets a random UID write to a volume.

---

## **18. Key Takeaways**

1. **PVC (you) → PV (automatic) → disk**, provisioned by a **StorageClass** and a **CSI driver**.
2. ROSA default: **EBS gp3-csi**, which is **RWO, single AZ, expandable**.
3. For **shared (RWX)** storage use **EFS** or **ODF**. (EFS operator is already on your cluster, but it needs an admin setup.)
4. `WaitForFirstConsumer` means a PVC stays **Pending** until a pod uses it, and the volume lands in the pod's AZ.
5. **RWO + RollingUpdate** can cause Multi-Attach. Use **`Recreate`** or StatefulSets.
6. **SCC fsGroup** makes volumes writable for the random UID.
7. **Snapshots ≠ backups.** Use **OADP** and keep copies off-cluster.
8. For real databases, use an **Operator**.

### **Common Commands**

```bash
oc get sc,pvc,pv
oc describe pvc <name>
oc set volume deploy/<name> --add --type=pvc --claim-size=1Gi --mount-path=/data
oc set volume deploy/<name> --list
oc patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
oc get volumesnapshot
```

---

**✅ Topic 15 Complete**

When ready, reply:
- ✅ **"Ready for Topic 16"** → Move to: Cluster Operators, Upgrades & the Machine Config Operator
- ❓ **"Need clarification on [section]"**
