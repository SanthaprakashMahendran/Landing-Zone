# **Topic 16: Cluster Operators, Upgrades & Machine Config ⭐ — Complete Notes**

> **Sandbox practicability:** ⚠️ Read-only at best.
> ✅ Console **Administration → Cluster Settings** (if visible), `oc get clusterversion`, `oc get co` (may be allowed).
> ❌ Starting upgrades, changing channels, editing MachineConfigs and pausing pools are admin tasks. On ROSA, **Red Hat SRE** runs upgrades anyway.
> The goal is to understand how the platform keeps itself running and updated.

---

## **Table of Contents**
1. Introduction
2. The Operator-Driven Platform
3. Cluster Version Operator (CVO)
4. Cluster Operators (COs)
5. Reading Cluster Health
6. Update Channels & the Update Graph
7. How an Upgrade Works
8. Machine Config Operator (MCO) & RHCOS
9. MachineConfig & MachineConfigPool
10. Upgrade Blockers & Pre-Checks
11. Upgrading ROSA
12. Troubleshooting
13. Real-World Examples
14. Best Practices
15. Hands-on Lab (Sandbox)
16. Key Takeaways

---

## **1. Introduction**

In plain Kubernetes, upgrading a cluster means a **manual, multi-step process** (control plane, then nodes, then add-ons, hoping versions line up).

In OpenShift, **the cluster upgrades itself**:

```
You:  "Update to 4.16.8"
        │
        ▼
Cluster Version Operator  ──▶ updates every platform component (operators)
Machine Config Operator   ──▶ updates the OS on every node (reboot, in order)
```

Everything (API server, ingress, DNS, console, network, monitoring, OS) is a **managed component** that moves together as one tested release.

---

## **2. The Operator-Driven Platform**

OpenShift is built of **operators that manage the platform itself** (not to be confused with OLM operators in Topics 7 and 8).

```
                    Cluster Version Operator (CVO)
                               │ rolls out the release image
   ┌─────────┬──────────┬──────┴──────┬───────────┬────────────┐
   ▼         ▼          ▼             ▼           ▼            ▼
 kube-    ingress    network      authentication  console   machine-config
 apiserver                                                       │
 (each is a "ClusterOperator", ~30+ in total)                   ▼
                                                      updates node OS (RHCOS)
```

| Kind | Examples | Managed by |
|---|---|---|
| **Platform (cluster) operators** | `kube-apiserver`, `ingress`, `dns`, `network`, `console`, `monitoring`, `machine-config` | **CVO** (this topic) |
| **Add-on operators** | Pipelines, GitOps, EFS CSI, Ansible, Camel K | **OLM** (Topics 7 and 8), what's in your screenshot |

---

## **3. Cluster Version Operator (CVO)**

The **CVO** is the operator of operators. It:
1. Reads the desired **release image** (a single image listing all component images and versions)
2. **Applies manifests** for each cluster operator, in a defined order
3. **Waits** until each operator reports healthy
4. Reports overall progress

### **ClusterVersion object**

```bash
oc get clusterversion
```

```
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.16.8    True        False         3d      Cluster version is 4.16.8
```

```bash
oc get clusterversion version -o yaml
```

Key fields:

| Field | Meaning |
|---|---|
| `spec.channel` | Update channel (for example `stable-4.16`) |
| `spec.desiredUpdate` | The version being moved to |
| `status.desired` | Current target release |
| `status.history` | List of past updates (state `Completed` or `Partial`) |
| `status.availableUpdates` | Recommended next versions |
| `status.conditions` | `Available`, `Progressing`, `Failing`, `Upgradeable`, `RetrievedUpdates` |

```bash
oc get clusterversion version -o jsonpath='{.status.desired.version}{"\n"}'
oc get clusterversion version -o jsonpath='{range .status.history[*]}{.version}{"\t"}{.state}{"\n"}{end}'
oc version
```

---

## **4. Cluster Operators (COs)**

Each platform component reports through a **ClusterOperator** object.

```bash
oc get clusteroperators         # short: oc get co
```

```
NAME                  VERSION  AVAILABLE  PROGRESSING  DEGRADED  SINCE
authentication        4.16.8   True       False        False     3d
console               4.16.8   True       False        False     3d
dns                   4.16.8   True       False        False     3d
image-registry        4.16.8   True       False        False     3d
ingress               4.16.8   True       False        False     3d
machine-config        4.16.8   True       False        False     3d
monitoring            4.16.8   True       False        False     3d
network               4.16.8   True       False        False     3d
...
```

### **The three conditions**

| Condition | Healthy value | Meaning |
|---|---|---|
| **Available** | `True` | The component works |
| **Progressing** | `False` | Not changing right now (`True` during an update) |
| **Degraded** | `False` | Something is wrong but it may still work |

> **Healthy cluster:** `Available=True`, `Progressing=False`, `Degraded=False` for **every** operator.

### **Common operators and what they own**

| Operator | Owns |
|---|---|
| `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd` | The Kubernetes control plane |
| `openshift-apiserver` | OpenShift APIs (routes, builds, imagestreams) |
| `authentication` / `oauth-apiserver` | OAuth and login (Topic 12) |
| `ingress` | Routers (Topic 5/14) |
| `dns`, `network` | CoreDNS, OVN-Kubernetes (Topic 14) |
| `image-registry` | Internal registry (Topic 11) |
| `storage`, `csi-snapshot-controller` | CSI drivers (Topic 15) |
| `monitoring` | Prometheus stack (Topic 18) |
| `machine-api`, `cluster-autoscaler` | Machines (Topic 17) |
| `machine-config` | Node OS configuration |
| `operator-lifecycle-manager*` | OLM (Topic 8) |
| `console` | Web console |

```bash
oc describe co ingress                 # conditions with messages, related objects
oc get co ingress -o yaml
```

---

## **5. Reading Cluster Health**

### **Quick health check**

```bash
oc get clusterversion
oc get co | grep -v "True.*False.*False"      # anything NOT healthy
oc get nodes                                  # all Ready?
oc get mcp                                    # pools Updated=True, Degraded=False
oc get pods -A | grep -Ev "Running|Completed" # failing pods
oc get csr | grep Pending                     # certificate requests stuck
```

### **Console**
**Administration → Cluster Settings** shows the version, channel, available updates and cluster operator status. The **Overview** page has the **Status** card (Cluster, Control Plane, Operators).

### **What each symptom means**

| You see | Meaning |
|---|---|
| `Progressing=True` for many COs | An update is running (normal) |
| One CO `Degraded=True` | Look at `oc describe co <name>` message |
| CO `Available=False` | Real outage of that component |
| `Failing=True` on ClusterVersion | The update can't proceed |

---

## **6. Update Channels & the Update Graph**

### **Channels**

| Channel | Meaning | Use |
|---|---|---|
| `candidate-4.y` | Release candidates, no support guarantee | Testing |
| `fast-4.y` | Available when released | Early adopters |
| **`stable-4.y`** | Delayed until data shows it's safe | ✅ **Production default** |
| `eus-4.y` | Extended Update Support (even minors like 4.14, 4.16) | Fewer, longer-lived upgrades |

The channel name includes the **minor version** (`stable-4.16`). To move to 4.17 you first change channel to `stable-4.17`.

### **Update graph**

Red Hat's **OpenShift Update Service** (Cincinnati) publishes which versions can upgrade to which, based on tested paths. The CVO asks it for **`availableUpdates`**.

```bash
oc adm upgrade                    # shows current version and recommended updates
oc adm upgrade channel stable-4.17    # change channel (admin ❌)
```

- **Patch (z-stream) updates**: 4.16.5 → 4.16.8, safe and frequent
- **Minor updates**: 4.16 → 4.17, **one minor at a time** (no skipping), except **EUS-to-EUS** (4.14 → 4.16) through a supported process
- Disconnected clusters mirror the graph with the **OpenShift Update Service Operator**

---

## **7. How an Upgrade Works**

```
1. Admin picks a version     oc adm upgrade --to=4.16.8
2. CVO downloads the release image (verifies its signature)
3. CVO updates operators in order (dependency "run levels")
      etcd → kube-apiserver → controller-manager/scheduler → ... → console, monitoring
4. machine-config operator rolls out the new OS (rpm-ostree image) to nodes
      control plane nodes first, then workers, a few at a time
      each node: cordon → drain → update → reboot → uncordon
5. CVO reports  "Cluster version is 4.16.8"
```

### **Commands (admin ❌)**

```bash
oc adm upgrade                            # what's available
oc adm upgrade --to-latest=true           # latest in this channel
oc adm upgrade --to=4.16.8                # a specific version
oc get clusterversion -w                  # watch it
oc adm upgrade --clear                    # cancel an in-progress update (if safe)
```

### **Timing (rough)**

| Cluster | Time |
|---|---|
| Control plane update | 30–60 min |
| Each worker node | A few minutes (drain + reboot) |
| Whole cluster | 1–3 hours, depending on node count and PodDisruptionBudgets |

### **What your apps must do to survive it**
Nodes **drain and reboot**, so your pods get evicted and rescheduled:
- **2+ replicas** across nodes (anti-affinity or topology spread)
- **PodDisruptionBudget** so enough replicas stay up
- Correct **readiness probes** (Topic 9)
- Tolerate pod restarts (graceful shutdown)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: landing-app
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: landing-app
```

A PDB that allows **zero** disruptions (`minAvailable` = replicas) **blocks node drains and stalls the upgrade**.

---

## **8. Machine Config Operator (MCO) & RHCOS**

Nodes run **Red Hat Enterprise Linux CoreOS (RHCOS)**:
- **Immutable, image-based** OS (rpm-ostree). You don't SSH in and `yum install`
- OS is **updated as a whole image** with the cluster release
- Configuration is **declared** and applied by the MCO, not edited by hand

```
Release image ──includes──▶ RHCOS OS image + kubelet + CRI-O
MCO ──applies──▶ every node reboots into the new OS image
```

| Component | Role |
|---|---|
| **machine-config-operator** | Manages OS config and updates |
| **machine-config-controller** | Renders configuration per pool |
| **machine-config-daemon (on each node)** | Applies the config, drains, reboots |
| **Ignition** | First-boot provisioning (disks, files, users) |

---

## **9. MachineConfig & MachineConfigPool**

### **MachineConfigPool (MCP)**

A group of nodes that get the same configuration:

```bash
oc get machineconfigpool       # short: oc get mcp
```

```
NAME     CONFIG          UPDATED  UPDATING  DEGRADED  MACHINECOUNT  READYMACHINECOUNT
master   rendered-...    True     False     False     3             3
worker   rendered-...    True     False     False     6             6
```

| Pool | Nodes |
|---|---|
| `master` (or `control-plane`) | Control plane |
| `worker` | Worker nodes |
| custom (`infra`, `gpu`) | A subset you define by label |

### **MachineConfig**

A declarative change to the node OS (files, systemd units, kernel arguments, ...):

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-chrony
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/chrony.conf
          mode: 420
          overwrite: true
          contents:
            source: data:,pool%20169.254.169.123%20iburst%0A
```

- Applying one **reboots** every node in that pool (rolling).
- **Never hand-edit nodes.** The MCO will **revert** the changes (`config drift` makes the pool `Degraded`).

### **Pausing and speed**

```bash
oc patch mcp worker --type merge -p '{"spec":{"paused":true}}'            # hold node updates
oc patch mcp worker --type merge -p '{"spec":{"maxUnavailable":2}}'       # update 2 at a time
```

(Admin ❌. Used to separate control-plane updates from worker updates.)

### **KubeletConfig**
For kubelet tuning (`maxPods`, eviction thresholds), use a **KubeletConfig** object instead of editing files.

---

## **10. Upgrade Blockers & Pre-Checks**

| Check | Why |
|---|---|
| **`Upgradeable=False`** on ClusterVersion | Something blocks **minor** upgrades. Read the message |
| **Deprecated/removed APIs in use** | An API your workloads use disappears in the next version (the alert `APIRemovedInNextReleaseInUse`). Admins must acknowledge: `oc -n openshift-config patch cm admin-acks ...` |
| **Add-on operators not compatible** | OLM Subscriptions with `olm.maxOpenShiftVersion` block upgrades (Topic 8). Update the operator first |
| **Degraded cluster operators** | Fix before upgrading |
| **MCPs not Updated** | Finish previous updates first |
| **PDBs with no allowed disruptions** | Drains hang |
| **Insufficient capacity** | Draining a node needs spare room elsewhere |
| **Backups** | Take an etcd backup before minor upgrades on self-managed clusters (not needed on ROSA) |

```bash
oc get clusterversion version -o jsonpath='{.status.conditions[?(@.type=="Upgradeable")]}'
oc get apirequestcounts | grep -i removedInRelease      # which deprecated APIs are being called
oc get pdb -A
```

---

## **11. Upgrading ROSA**

On ROSA, **Red Hat SRE** keeps the cluster up to date, but you control **when**.

```bash
rosa list upgrades --cluster=demo                         # available versions
rosa upgrade cluster --cluster=demo --version=4.16.8      # schedule now
rosa upgrade cluster --cluster=demo --version=4.16.8 \
     --schedule-date=2026-11-02 --schedule-time=02:00     # schedule for a window
rosa list upgrade-policies --cluster=demo                 # see scheduled upgrades
```

| ROSA type | What upgrades |
|---|---|
| **ROSA Classic** | Control plane and workers upgrade together |
| **ROSA HCP** | **Control plane** and **each machine pool** upgrade **separately** (`rosa upgrade machinepool ...`), so workers can lag by up to a couple of minor versions |

| Responsibility | You | Red Hat SRE |
|---|---|---|
| Choose the version and the window | ✅ | |
| Run the update | | ✅ |
| Keep apps resilient (replicas, PDBs) | ✅ | |
| Fix platform problems during the update | | ✅ |
| Compatibility of your add-on operators | ✅ | |

> Your sandbox cluster is upgraded by Red Hat, with no controls for you. Expect the version to change.

---

## **12. Troubleshooting**

| Symptom | Check | Cause / fix |
|---|---|---|
| Update stuck at X% | `oc get co`, `oc describe clusterversion` | A CO is `Progressing`/`Degraded`. Read its message |
| CO `Degraded` | `oc describe co <name>` | Follow `Related Objects` and the operator pod logs |
| Node stuck `SchedulingDisabled` | `oc get nodes`, `oc get mcp` | Drain blocked by a PDB or a stuck pod |
| MCP `Degraded` | `oc describe mcp worker` | A bad MachineConfig, or node drift |
| `Upgradeable=False` | `oc get clusterversion -o yaml` | Operator incompatibility, API acknowledgements, degraded operators |
| Can't see updates | `oc get clusterversion` → `RetrievedUpdates` | No access to the update service (proxy or disconnected) |
| Pods evicted and an app outage during the upgrade | | Single replica or no PDB, so add replicas |
| Console is down | `oc get co console`, `oc get pods -n openshift-console` | Console or ingress operator problem |

### **Debug order**

```bash
oc get clusterversion
oc get co | grep -v "True.*False.*False"
oc describe co <degraded-operator>
oc get mcp; oc get nodes
oc get pods -n openshift-<operator-namespace>
oc logs -n openshift-<ns> deploy/<operator>          # admin
oc adm must-gather                                    # collect a support bundle (admin)
```

---

## **13. Real-World Examples**

### **Example 1: Pre-upgrade checklist (script-style)**

```bash
oc get clusterversion
oc get co | awk 'NR==1 || !($3=="True" && $4=="False" && $5=="False")'
oc get mcp
oc get nodes | grep -v " Ready"
oc get pdb -A
oc get clusterversion version -o jsonpath='{.status.conditions[?(@.type=="Upgradeable")].message}'
```

### **Example 2: Make `landing-app` upgrade-safe**

```yaml
spec:
  replicas: 2
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels: { app: landing-app }
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: landing-app }
spec:
  minAvailable: 1
  selector:
    matchLabels: { app: landing-app }
```

### **Example 3: Plan an upgrade window on ROSA**

```bash
rosa list upgrades -c demo
rosa upgrade cluster -c demo --version 4.16.8 --schedule-date 2026-11-02 --schedule-time 02:00
```

### **Example 4: Find what changed after the upgrade**

```bash
oc get clusterversion version -o jsonpath='{range .status.history[*]}{.startedTime}{"\t"}{.version}{"\t"}{.state}{"\n"}{end}'
```

---

## **14. Best Practices**

- ✅ Run the **`stable`** channel in production, and stay within support (**upgrade at least every few months**)
- ✅ Make apps **upgrade-safe**: 2+ replicas, spread across nodes, PDBs, readiness probes
- ✅ **Test upgrades in a non-prod cluster** with the same operators
- ✅ Keep add-on **operators up to date** before a minor upgrade
- ✅ Watch **`oc get co`** (alert on Degraded, Available=False)
- ✅ Use **MachineConfig** (via GitOps) instead of changing nodes manually
- ✅ On ROSA, **schedule upgrades** in a maintenance window
- ❌ Don't SSH into nodes to "fix" things (the MCO reverts them)
- ❌ Don't set PDBs that allow zero disruptions
- ❌ Don't ignore deprecated-API alerts

---

## **15. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted · ❌ admin only

| # | Task | Status |
|---|---|---|
| 1 | Console → **Administration → Cluster Settings**, and note the version and channel | ⚠️ |
| 2 | `oc version` (client and server) | ✅ |
| 3 | `oc get clusterversion` and `oc get co` | ⚠️ |
| 4 | Identify which COs relate to topics you've done (ingress, dns, network, image-registry) | ⚠️ |
| 5 | `oc describe co ingress` and read the conditions | ⚠️ |
| 6 | `oc get mcp` and `oc get nodes` | ⚠️ |
| 7 | Add a PDB and a second replica to `landing-app` and confirm with `oc get pdb` | ✅ |
| 8 | Read `oc adm upgrade` output | ⚠️ |
| 9 | Start an upgrade, edit a MachineConfig, or pause a pool | ❌ |

### **Expected learning outcomes**
- You can explain CVO, ClusterOperators and the MCO, and how they differ from OLM operators.
- You can read cluster health at a glance.
- You know how to make an app survive node reboots.

---

## **16. Key Takeaways**

1. OpenShift is **operators all the way down**. The **CVO** updates the platform, and the **MCO** updates node OS.
2. Every component reports as a **ClusterOperator**. Healthy = `Available=True`, `Progressing=False`, `Degraded=False`.
3. **Channels** (`stable-4.y`) and the **update graph** decide what versions you can move to. **One minor at a time.**
4. Upgrades **drain and reboot nodes**. Your apps need replicas, readiness probes and PDBs.
5. Nodes are **RHCOS, immutable**. Change them through **MachineConfig**, never by hand.
6. **`Upgradeable=False`** comes from degraded operators, removed APIs and incompatible add-on operators.
7. On **ROSA**, you pick the time and Red Hat SRE runs the upgrade (HCP: control plane and machine pools separately).

### **Common Commands**

```bash
oc get clusterversion
oc get co
oc describe co <name>
oc get mcp
oc get nodes
oc adm upgrade
oc get pdb -A
rosa list upgrades -c <cluster>
```

---

**✅ Topic 16 Complete**

When ready, reply:
- ✅ **"Ready for Topic 17"** → Move to: Machine API, MachineSets & Autoscaling
- ❓ **"Need clarification on [section]"**
