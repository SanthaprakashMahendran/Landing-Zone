# **Topic 13: ResourceQuota, LimitRange & ClusterResourceQuota — Complete Notes**

> **Sandbox practicability:** ⚠️ Read-only.
> ✅ View the quota and limits applied to `santha-dev`, see how your pods are affected, and test hitting a limit.
> ❌ Creating or editing `ResourceQuota`, `LimitRange` and `ClusterResourceQuota` needs admin rights. The `admin` project role can **view** quotas but not change them.

---

## **Table of Contents**
1. Introduction
2. Why Quotas & Limits Exist
3. Requests vs Limits Refresher
4. ResourceQuota
5. LimitRange
6. How They Work Together
7. OpenShift Extras: Image & ImageStream Limits
8. ClusterResourceQuota (Multi-Project)
9. Project Templates (Default Quotas for New Projects)
10. Checking Usage
11. Hitting the Limits (What Errors Look Like)
12. Troubleshooting
13. Real-World Examples
14. Best Practices
15. Hands-on Lab (Sandbox)
16. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

```
ResourceQuota:        "This project may use at most X in total."
LimitRange:           "Each pod/container in this project must be between A and B (with defaults)."
ClusterResourceQuota: "These several projects together may use at most X." (OpenShift only)
```

In a multi-tenant cluster (like the sandbox), quotas stop one project from eating the whole cluster.

```
Cluster capacity
 ├── Project team-a  (quota: 4 CPU, 8 Gi)
 ├── Project team-b  (quota: 2 CPU, 4 Gi)
 └── Project santha-dev  (your sandbox quota)
```

---

## **2. Why Quotas & Limits Exist**

| Problem without them | Result |
|---|---|
| One runaway app uses all memory | Other teams' pods get evicted |
| A developer creates 500 pods by mistake | Scheduler and API slow down |
| Unlimited PVCs | Storage bill explodes |
| Pods with no limits | Noisy neighbors and unpredictable performance |
| Pods with no requests | The scheduler packs nodes badly |

---

## **3. Requests vs Limits Refresher**

| | Request | Limit |
|---|---|---|
| Meaning | Guaranteed amount; used for **scheduling** | Maximum allowed |
| CPU over limit | | **Throttled** |
| Memory over limit | | **OOMKilled** |
| Quota counts | `requests.cpu`, `requests.memory` | `limits.cpu`, `limits.memory` |

```yaml
resources:
  requests: { cpu: 50m,  memory: 128Mi }
  limits:   { cpu: 500m, memory: 256Mi }
```

Units: CPU `1` = 1 core, `500m` = 0.5 core. Memory `Mi`/`Gi` (binary).

---

## **4. ResourceQuota**

A **ResourceQuota** caps the **total** resources in **one namespace**.

### **Example**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-and-objects
  namespace: santha-dev
spec:
  hard:
    # compute
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    # object counts
    pods: "20"
    services: "10"
    secrets: "30"
    configmaps: "30"
    persistentvolumeclaims: "5"
    count/deployments.apps: "10"
    # storage
    requests.storage: 20Gi
    # OpenShift
    openshift.io/imagestreams: "20"
```

### **What can be limited**

| Category | Examples |
|---|---|
| **Compute** | `requests.cpu`, `limits.cpu`, `requests.memory`, `limits.memory` |
| **Object counts** | `pods`, `services`, `secrets`, `configmaps`, `persistentvolumeclaims`, `count/<resource>.<group>` |
| **Storage** | `requests.storage`, `<storageclass>.storageclass.storage.k8s.io/requests.storage` |
| **Extended** | `requests.nvidia.com/gpu`, `openshift.io/imagestreams` |

### **Scopes**

Apply a quota only to a subset of pods:

```yaml
spec:
  hard:
    pods: "5"
  scopes: ["BestEffort"]        # only pods with no requests/limits
```

| Scope | Matches |
|---|---|
| `BestEffort` | Pods with no requests or limits |
| `NotBestEffort` | Pods with at least one request/limit |
| `Terminating` / `NotTerminating` | Pods with or without `activeDeadlineSeconds` (build and job pods) |
| `PriorityClass` | Pods of given priority classes |

### **The key rule**

> If a **compute quota** exists for CPU or memory, **every new pod must declare that resource** (request and/or limit), or it's **rejected**, unless a **LimitRange** supplies defaults.

---

## **5. LimitRange**

A **LimitRange** sets **per-object** minimums, maximums and **defaults** inside a namespace.

### **Example**

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: santha-dev
spec:
  limits:
    - type: Container
      default:                 # applied as the limit if none given
        cpu: 500m
        memory: 512Mi
      defaultRequest:          # applied as the request if none given
        cpu: 100m
        memory: 128Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: "2"
        memory: 2Gi
      maxLimitRequestRatio:    # limit/request may not exceed this
        cpu: "10"
    - type: Pod
      max:
        cpu: "4"
        memory: 4Gi
    - type: PersistentVolumeClaim
      max:
        storage: 10Gi
      min:
        storage: 1Gi
```

### **What each part does**

| Field | Meaning |
|---|---|
| `default` | The **limit** assigned when a container declares none |
| `defaultRequest` | The **request** assigned when a container declares none |
| `min` / `max` | Requests and limits outside this range are **rejected** |
| `maxLimitRequestRatio` | Stops huge "burst" gaps (limit 100× request) |

### **Types**

| `type` | Applies to |
|---|---|
| `Container` | Each container |
| `Pod` | The sum of containers in a pod |
| `PersistentVolumeClaim` | PVC size |
| `openshift.io/Image` | Image size |
| `openshift.io/ImageStream` | Number of tags and images per stream |

---

## **6. How They Work Together**

```
Create a pod
    │
    ▼
LimitRange (admission):  fill in defaults; check min/max      ──▶ reject if violating
    │
    ▼
ResourceQuota (admission): would the project total exceed hard?  ──▶ reject if yes
    │
    ▼
Pod created and scheduled
```

| | LimitRange | ResourceQuota |
|---|---|---|
| Scope | Each pod/container/PVC | The whole namespace total |
| Sets defaults? | ✅ Yes | ❌ No |
| Can reject? | Yes (outside min/max) | Yes (over total) |
| Purpose | Sane sizes for each workload | A fair budget for each team |

**They almost always come as a pair.** The LimitRange gives defaults so developers who forget `resources:` still pass the quota check.

---

## **7. OpenShift Extras: Image & ImageStream Limits**

Because builds create images, OpenShift adds limits for them:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: image-limits
spec:
  limits:
    - type: openshift.io/Image
      max:
        storage: 1Gi                # reject images larger than 1 Gi
    - type: openshift.io/ImageStream
      max:
        openshift.io/image-tags: "20"
        openshift.io/images: "50"
```

And in a ResourceQuota:

```yaml
spec:
  hard:
    openshift.io/imagestreams: "10"
```

### **Build pods and quota**
Build pods are **real pods** that count against `requests.cpu`/`limits.memory`. A heavy S2I build (npm install) in a tight quota can fail or stay **Pending**. Build resource settings come from the BuildConfig (`spec.resources`) or the LimitRange defaults. (See Topic 10.)

---

## **8. ClusterResourceQuota (Multi-Project)**

**OpenShift-only.** A Kubernetes ResourceQuota is **per namespace**. A **ClusterResourceQuota (CRQ)** is one budget shared by **many projects**, selected by label or owner.

### **By annotation (all projects owned by a user)**

```yaml
apiVersion: quota.openshift.io/v1
kind: ClusterResourceQuota
metadata:
  name: for-santha
spec:
  quota:
    hard:
      pods: "20"
      requests.cpu: "4"
      requests.memory: 8Gi
  selector:
    annotations:
      openshift.io/requester: santha
```

### **By label (a team's projects)**

```yaml
spec:
  selector:
    labels:
      matchLabels:
        team: payments
  quota:
    hard:
      limits.cpu: "20"
      limits.memory: 40Gi
```

### **When to use**

| Need | Tool |
|---|---|
| Cap each project separately | ResourceQuota |
| Cap a **team** that owns several projects | ClusterResourceQuota |
| Cap everything a user creates | ClusterResourceQuota with the `requester` annotation |

```bash
oc get clusterresourcequota                          # admin
oc describe clusterresourcequota for-santha          # admin
oc describe AppliedClusterResourceQuota -n santha-dev   # ✅ any project member can view
```

`AppliedClusterResourceQuota` is the project-side view: **this is how you see a CRQ that affects you** even without cluster rights.

---

## **9. Project Templates (Default Quotas for New Projects)**

Admins can edit the **project request template** so each new project automatically gets a quota, a LimitRange, and a NetworkPolicy:

```bash
oc adm create-bootstrap-project-template -o yaml > template.yaml
# add ResourceQuota, LimitRange, NetworkPolicy objects to the template
oc create -f template.yaml -n openshift-config

oc edit project.config.openshift.io/cluster
# spec:
#   projectRequestTemplate:
#     name: project-request
```

This is how enterprise clusters give **every new project sane defaults** (also used with the `self-provisioner` controls from Topic 12).

> ❌ Admin only.

---

## **10. Checking Usage**

```bash
oc get quota                             # all quotas in the project
oc describe quota                        # used vs hard
oc get limitrange
oc describe limitrange
oc describe AppliedClusterResourceQuota  # CRQs that apply to this project
oc adm top pod                           # live CPU/memory (needs metrics)
oc describe project santha-dev
```

### **Reading `oc describe quota`**

```
Name:            compute-and-objects
Resource         Used    Hard
--------         ----    ----
limits.cpu       500m    4
limits.memory    256Mi   8Gi
pods             1       20
requests.cpu     50m     2
```

`Used/Hard` shows how much headroom you have. Check this **before** scaling up.

### **Console**
Administration/Home → **Projects → santha-dev → ResourceQuotas** tab, or the **Project Overview** utilization charts.

---

## **11. Hitting the Limits (What Errors Look Like)**

### **Over quota**

```
Error creating: pods "landing-app-xxx" is forbidden: exceeded quota: compute-and-objects,
requested: limits.memory=256Mi, used: limits.memory=8Gi, limited: limits.memory=8Gi
```

- With a **Deployment**, you see no new pods and `oc describe rs` shows the error. The Deployment doesn't fail loudly.
- `oc get events` is where it appears.

### **No resources specified (when quota on compute exists)**

```
Error creating: pods "x" is forbidden: failed quota: compute-and-objects:
must specify limits.cpu for: app; limits.memory for: app; requests.cpu ...
```

**Fix:** add `resources:` to the container or ask for a LimitRange default.

### **Outside LimitRange**

```
pods "x" is forbidden: maximum memory usage per Container is 2Gi, but limit is 4Gi
```

### **PVC over the limit**

```
persistentvolumeclaims "data" is forbidden: exceeded quota ... requests.storage
```

---

## **12. Troubleshooting**

| Symptom | Check | Cause / fix |
|---|---|---|
| `scale up` does nothing | `oc describe rs <name>` → Events | Quota exhausted. Free resources or request more |
| Pod rejected: "must specify limits..." | `oc describe quota` | Add `resources:` to the Deployment |
| Build stuck **Pending** | `oc describe build`, `oc describe quota` | Not enough quota for the build pod, so lower the build `resources` |
| Pod `OOMKilled` | `oc describe pod` → Last State | Memory limit too low. Raise it (within `max`) |
| App slow, never killed | `oc adm top pod` | CPU **throttling** at the limit |
| Everything fits but the pod is `Pending` | `oc describe pod` → Events | Cluster has no node capacity (`Insufficient cpu`). That's not a quota issue |
| LimitRange default surprises you | `oc describe limitrange` | Defaults applied silently to pods with no `resources` |
| Can't change quota | `oc auth can-i update resourcequota` | Admin only. Ask the platform team |

---

## **13. Real-World Examples**

### **Example 1: Sizing the `landing-app` to fit a small quota**

```yaml
resources:
  requests: { cpu: 50m,  memory: 128Mi }
  limits:   { cpu: 500m, memory: 256Mi }
```

With `limits.memory: 8Gi` that's about 32 pods worth of memory. With `pods: 20`, the **pod count** is the real cap. Check both numbers.

### **Example 2: A standard "small team" bundle (admin)**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: team-quota }
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "40"
    persistentvolumeclaims: "10"
    requests.storage: 50Gi
---
apiVersion: v1
kind: LimitRange
metadata: { name: team-limits }
spec:
  limits:
    - type: Container
      defaultRequest: { cpu: 100m, memory: 128Mi }
      default:        { cpu: 500m, memory: 512Mi }
      max:            { cpu: "2",  memory: 2Gi }
```

### **Example 3: Prove a quota works (safe test in the sandbox)**

```bash
oc describe quota                                  # note the pods limit
oc scale deploy/landing-app --replicas=100
oc get rs                                          # DESIRED 100, READY stays low
oc describe rs <latest-rs> | tail -20              # "exceeded quota" in Events
oc scale deploy/landing-app --replicas=1           # put it back
```

### **Example 4: Why did my build not start?**

```bash
oc get build
oc describe build landing-app-3 | tail
oc describe quota
oc describe pod landing-app-3-build | grep -A5 Events
```

---

## **14. Best Practices**

- ✅ **Pair** every ResourceQuota with a **LimitRange** (defaults make quotas painless)
- ✅ Set **requests and limits** on every workload, and treat it as part of "done"
- ✅ Choose **requests close to real usage**, because over-requesting wastes quota
- ✅ Quota **object counts** too (`pods`, `secrets`, `persistentvolumeclaims`), since not just CPU and memory
- ✅ Use **ClusterResourceQuota** for teams that own several projects
- ✅ Use a **project template** to apply defaults to every new project
- ✅ Alert at **80%** of quota usage
- ✅ Keep quotas in **Git** (GitOps)
- ❌ Don't set `limits` far above `requests` (the ratio rule hurts predictability)
- ❌ Don't leave quotas at the defaults forever. Review them each quarter

---

## **15. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted · ❌ admin only

| # | Task | Status |
|---|---|---|
| 1 | `oc get quota` and `oc describe quota`, then record each limit | ✅ |
| 2 | `oc get limitrange` and `oc describe limitrange` | ✅ |
| 3 | `oc describe AppliedClusterResourceQuota` | ✅ (may be empty) |
| 4 | Create a pod with **no** `resources` and check the requests/limits it received (from the LimitRange): `oc get pod <p> -o jsonpath='{.spec.containers[0].resources}'` | ✅ |
| 5 | Scale `landing-app` high, read the quota error in the ReplicaSet events, and scale back | ✅ |
| 6 | Set a memory limit of `20Mi`, watch `OOMKilled`, and fix it | ✅ |
| 7 | `oc adm top pod` and compare usage with requests | ✅ (metrics permitting) |
| 8 | `oc auth can-i create resourcequota -n santha-dev` (expect "no") | ✅ |
| 9 | Create your own ResourceQuota/LimitRange (**use your own cluster later**) | ❌ |
| 10 | Create a ClusterResourceQuota | ❌ |

### **Expected learning outcomes**
- You know your sandbox's real limits and can size workloads to fit.
- You can read quota errors and say which object caused them.
- You understand how LimitRange defaults make quotas workable.

---

## **16. Key Takeaways**

1. **ResourceQuota = project total**, and **LimitRange = per-object size and defaults**.
2. If a compute quota exists, **pods must declare resources**, or a LimitRange must supply defaults.
3. **CPU over limit is throttled; memory over limit is OOMKilled.**
4. **ClusterResourceQuota** (OpenShift only) shares one budget across several projects.
5. OpenShift can limit **images and ImageStreams**, and builds count against quota like any pod.
6. **Project templates** apply quotas automatically to every new project.
7. Quota failures are **quiet** with Deployments, so read **`oc describe rs`** and **`oc get events`**.
8. In a sandbox you can **see** quotas but not change them.

### **Common Commands**

```bash
oc get quota,limitrange
oc describe quota
oc describe AppliedClusterResourceQuota
oc adm top pod
oc describe rs <name>
oc get events --sort-by=.lastTimestamp
oc set resources deploy/<name> --requests=cpu=50m,memory=128Mi --limits=cpu=500m,memory=256Mi
```

---

**✅ Topic 13 Complete**

When ready, reply:
- ✅ **"Ready for Topic 14"** → Move to: OpenShift Networking
- ❓ **"Need clarification on [section]"**
