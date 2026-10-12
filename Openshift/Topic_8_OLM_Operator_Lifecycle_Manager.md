# **Topic 8: OLM — Operator Lifecycle Manager ⭐ — Complete Notes**

> **Sandbox practicability:** ⚠️ Read-only in most sandboxes.
> ✅ View **Installed Operators**, browse **OperatorHub**, run `oc get packagemanifests`, read CSVs.
> ❌ Installing operators cluster-wide usually needs `cluster-admin`. Check with `oc auth can-i create subscriptions -n santha-dev`.

---

## **Table of Contents**
1. Introduction
2. What is OLM?
3. Why OLM Exists
4. OLM Architecture
5. OLM Custom Resources (The 5 Objects)
6. CatalogSource & Catalogs
7. Channels & PackageManifests
8. OperatorGroup & Install Modes
9. Subscription & InstallPlan
10. ClusterServiceVersion (CSV)
11. Installing an Operator (Step by Step)
12. Upgrades
13. Dependency Resolution
14. Uninstalling Operators
15. OLM v1 (Next Generation)
16. Disconnected / Air-Gapped Clusters
17. Troubleshooting
18. Real-World Examples
19. Best Practices
20. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

**OLM = Operator Lifecycle Manager**, the component that installs, updates and manages Operators on the cluster.

**Think of it like:**
```
Operators:   The apps (PostgreSQL operator, Prometheus operator...)
OLM:         The app store + updater for those apps
OperatorHub: The shop window (the UI over the catalogs)
```

**OLM = package manager for Operators** (like `apt` or `brew`, but for the cluster).

---

## **2. What is OLM?**

### **Simple Explanation**

OLM is a set of controllers, **running by default in every OpenShift cluster**, that:
- Reads **catalogs** of available operators
- Installs the operator you pick (**Subscription**)
- Checks **who is allowed** to use it and **where** it watches (**OperatorGroup**)
- Keeps it **up to date** (channels and InstallPlans)
- Resolves **dependencies** between operators
- Cleans up on uninstall

### **What OLM is NOT**

| OLM does | OLM does NOT |
|---|---|
| Install and upgrade the **operator** | Manage your **application** (the operator does that) |
| Track operator versions | Run your database or app |
| Handle operator RBAC and CRDs | Replace Helm for ordinary apps |

```
You ──▶ OLM ──▶ installs Operator ──▶ Operator manages your app (database, Kafka...)
```

---

## **3. Why OLM Exists**

### **Problem Without OLM**

Installing an operator by hand means:

```bash
1. Create CRDs               kubectl apply -f crds.yaml
2. Create ServiceAccount     kubectl apply -f sa.yaml
3. Create Roles/Bindings     kubectl apply -f rbac.yaml
4. Create Deployment         kubectl apply -f operator.yaml
5. Upgrade later?            Repeat everything, hope CRDs didn't break
6. Two operators need the
   same CRD?                 Conflict, nobody owns it
```

### **OLM Solution**

```bash
oc apply -f subscription.yaml    # OLM does 1–4 and the upgrades
```

| Capability | Without OLM | With OLM |
|---|---|---|
| Install | Many manual YAMLs | One Subscription |
| Permissions | You write RBAC | Generated from the CSV |
| Upgrades | Manual, risky | Channel-based, can be automatic or approved |
| CRD ownership | Unclear | The CSV **owns** its CRDs |
| Dependencies | You track them | OLM resolves them |
| Versions | Whatever you applied | Catalog-defined, signed content |

---

## **4. OLM Architecture**

### **Two Controllers**

```
┌───────────────────── openshift-operator-lifecycle-manager ─────────────────────┐
│                                                                                │
│   Catalog Operator                         OLM Operator                        │
│   ─────────────────                        ────────────                        │
│   Watches CatalogSource,                   Watches ClusterServiceVersion,      │
│   Subscription, InstallPlan                OperatorGroup                       │
│   • Reads catalogs                         • Runs the CSV state machine        │
│   • Resolves dependencies                  • Creates operator Deployments      │
│   • Creates InstallPlans                   • Creates RBAC for the operator     │
└────────────────────────────────────────────────────────────────────────────────┘
```

| Component | Namespace | Job |
|---|---|---|
| **Catalog Operator** | `openshift-operator-lifecycle-manager` | Finds operators and versions, creates InstallPlans |
| **OLM Operator** | `openshift-operator-lifecycle-manager` | Installs what the InstallPlan says, then keeps it healthy |
| **Catalog pods** | `openshift-marketplace` | Serve the catalog content (gRPC) |
| **Packageserver** | `openshift-operator-lifecycle-manager` | Serves `PackageManifest` API from catalogs |

### **Flow Overview**

```
CatalogSource ──▶ (catalog pod serves list of operators + versions)
      │
      ▼
PackageManifest   "what can I install?"
      │
      ▼
Subscription      "I want operator X from channel Y"
      │
      ▼
InstallPlan       "here's exactly what will be created"  (approve if Manual)
      │
      ▼
CSV               "operator X v1.2.3 installed" ─▶ Deployment, RBAC, CRDs
```

---

## **5. OLM Custom Resources (The 5 Objects)**

| # | Resource | Short | Scope | Question it answers |
|---|---|---|---|---|
| 1 | **CatalogSource** | `catsrc` | Namespace | Where do operators come from? |
| 2 | **Subscription** | `sub` | Namespace | Which operator and channel do I want? |
| 3 | **InstallPlan** | `ip` | Namespace | What exactly will be installed or changed? |
| 4 | **ClusterServiceVersion** | `csv` | Namespace | Which version is installed, and is it healthy? |
| 5 | **OperatorGroup** | `og` | Namespace | Which namespaces does the operator serve? |

Read-only helper: **PackageManifest** (`packagemanifest`), the catalog entry for one operator.

### **How they relate**

```
CatalogSource ─(provides)─▶ PackageManifest
                                 │
Subscription ─(creates)─▶ InstallPlan ─(creates)─▶ CSV ─(creates)─▶ Deployment + RBAC
       │                                             │
       └──── lives in a namespace with an ───────────┘
                    OperatorGroup
```

---

## **6. CatalogSource & Catalogs**

### **What it is**

A **CatalogSource** points to an **index image** that contains operator bundles. OLM runs a pod for it and queries it.

### **Default catalogs in OpenShift**

All live in `openshift-marketplace`:

| Catalog | Content | Support |
|---|---|---|
| `redhat-operators` | Red Hat products (Pipelines, GitOps, Serverless, ODF) | Red Hat |
| `certified-operators` | Partner products (certified by Red Hat) | Vendor |
| `redhat-marketplace` | Commercial operators bought via the Red Hat Marketplace | Vendor |
| `community-operators` | Community-maintained | None (community) |

```bash
oc get catalogsource -n openshift-marketplace
oc get pods -n openshift-marketplace
```

### **CatalogSource YAML**

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: my-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/myorg/my-catalog-index:v1
  displayName: My Company Operators
  publisher: My Company
  updateStrategy:
    registryPoll:
      interval: 30m        # re-check the index image every 30 minutes
```

### **Disabling default catalogs**

```bash
oc patch OperatorHub cluster --type merge -p '{"spec":{"disableAllDefaultSources":true}}'
```

(Used in disconnected environments. See section 16.) ❌ Cluster-admin only.

---

## **7. Channels & PackageManifests**

### **Channels**

A **channel** is an upgrade track for an operator, similar to release tracks.

| Channel example | Meaning |
|---|---|
| `stable` | Latest stable release |
| `stable-1.2` | Stay on the 1.2 minor line (only patch updates) |
| `fast` / `candidate` | Earlier access, less tested |
| `latest` | Newest, might be unstable |

Each operator defines its own channels. **Always pick a pinned minor channel in production.**

### **PackageManifest**

```bash
# What operators are available?
oc get packagemanifests -n openshift-marketplace | head

# Details of one operator
oc describe packagemanifest openshift-gitops-operator -n openshift-marketplace
```

Look for:
- `Default Channel`
- `Channels:` each with the `Current CSV`
- `Catalog Source` and its namespace

### **Useful one-liners**

```bash
# Channels for an operator
oc get packagemanifest openshift-pipelines-operator-rh -n openshift-marketplace \
  -o jsonpath='{range .status.channels[*]}{.name}{"\t"}{.currentCSV}{"\n"}{end}'

# Supported install modes
oc get packagemanifest openshift-gitops-operator -n openshift-marketplace \
  -o jsonpath='{.status.channels[0].currentCSVDesc.installModes}'
```

> ✅ **Sandbox:** the PackageManifest API is readable by all authenticated users, so these commands should work.

---

## **8. OperatorGroup & Install Modes**

### **What an OperatorGroup does**

It tells OLM **which namespaces the operator may watch**, and grants it RBAC only there.

```
Namespace A  ─┐
Namespace B  ─┼─ OperatorGroup says: "operator watches A and B"
              │
Namespace C   ┘  (not watched, the operator cannot touch it)
```

### **Install Modes**

| Mode | Operator watches | Typical use |
|---|---|---|
| **OwnNamespace** | Only its own namespace | Isolated, per-team |
| **SingleNamespace** | One other namespace | Rare |
| **MultiNamespace** | A chosen list of namespaces | Shared between a few teams |
| **AllNamespaces** | Whole cluster | Platform-wide (most common, e.g. Pipelines, GitOps) |

The operator author declares which modes are supported (in the CSV). Check the **Managed Namespaces** column on the Installed Operators page. In your screenshot, operators such as Ansible Automation Platform run in their own namespace but show `openshift` there, meaning they manage that namespace.

### **OperatorGroup YAML**

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: my-og
  namespace: my-operators
spec:
  targetNamespaces:          # omit for AllNamespaces
    - team-a
    - team-b
```

| Spec | Result |
|---|---|
| `targetNamespaces: [my-operators]` | OwnNamespace |
| `targetNamespaces: [a, b]` | MultiNamespace |
| `spec: {}` (no targets) | AllNamespaces |

### **Rules**
- **One OperatorGroup per namespace.** Two groups in one namespace break installs.
- For AllNamespaces operators, install in **`openshift-operators`**, which has a global OperatorGroup.
- `oc get og -A` lists them.

---

## **9. Subscription & InstallPlan**

### **Subscription**

"I want this operator, from this catalog, on this channel."

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator          # package name
  source: redhat-operators                 # CatalogSource
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic           # or Manual
  # startingCSV: openshift-gitops-operator.v1.12.0   # optional pin
```

| Field | Meaning |
|---|---|
| `channel` | Which update track to follow |
| `name` | Package name (from `oc get packagemanifest`) |
| `source` / `sourceNamespace` | Which catalog |
| `installPlanApproval` | `Automatic` applies updates; `Manual` waits for approval |
| `startingCSV` | Install this exact version first |
| `config` | Env vars, resources and tolerations for the operator pod |

### **InstallPlan**

A **bill of materials**: every object OLM will create or change (CRDs, RBAC, CSV). Status `Complete` means it was applied.

```bash
oc get installplan -n openshift-operators
oc describe installplan install-xxxxx -n openshift-operators
```

### **Manual approval**

```bash
oc patch installplan install-xxxxx -n openshift-operators \
  --type merge -p '{"spec":{"approved":true}}'
```

### **Automatic vs Manual**

| | Automatic | Manual |
|---|---|---|
| Updates | Applied immediately | Wait for your approval |
| Risk | A breaking update lands unannounced | Safe, but you must watch |
| Best for | Dev and test | **Production** |

---

## **10. ClusterServiceVersion (CSV)**

### **What it is**

The CSV is the **installed operator** (one per version). It says:
- Which **Deployment** to run for the operator
- Which **permissions** (RBAC) it needs
- Which **CRDs it owns** and **requires**
- Install modes supported
- Display name, icon, description (what you see in the console)

### **CSV phases**

```
Pending → InstallReady → Installing → Succeeded
                                        │
                                  (new version arrives)
                                        ▼
                                   Replacing → Deleting (old CSV)
Failed  ← problem during install
```

| Phase | Meaning |
|---|---|
| Pending | Waiting for requirements (CRDs, permissions) |
| InstallReady | Requirements met |
| Installing | Creating the Deployment |
| **Succeeded** | Operator is running ✅ (the status in your screenshot) |
| Failed | Check `oc describe csv` for the reason |
| Replacing / Deleting | Upgrade in progress |

### **Commands**

```bash
oc get csv -A                                  # all installed operators
oc get csv -n openshift-operators
oc describe csv <name> -n <ns>
oc get csv <name> -n <ns> -o jsonpath='{.spec.customresourcedefinitions.owned[*].name}'
```

The **Provided APIs** column in your screenshot (Automation Controller, Automation Hub, ...) comes from `spec.customresourcedefinitions.owned`.

### **CSV copies**

For AllNamespaces operators, OLM **copies the CSV into every namespace** so each project can see them. Those copies are why `santha-dev` lists operators that actually run elsewhere (look for the reason text: "The operator is running in ... but is managing this namespace").

---

## **11. Installing an Operator (Step by Step)**

### **Method 1: Console**
1. **Ecosystem (or Operators) → OperatorHub**
2. Search (for example `OpenShift GitOps`) → **Install**
3. Choose **channel**, **install mode**, **namespace**, **update approval**
4. **Install** → watch **Installed Operators** until **Succeeded**

### **Method 2: CLI**

```bash
# 1. Namespace (skip for openshift-operators)
oc create namespace my-operators

# 2. OperatorGroup
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: my-og
  namespace: my-operators
spec:
  targetNamespaces:
    - my-operators
EOF

# 3. Subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator-rh
  namespace: my-operators
spec:
  channel: latest
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# 4. Verify
oc get sub,ip,csv -n my-operators
oc get pods -n my-operators
```

### **What happens internally**

```
1. Subscription created
2. Catalog Operator resolves the package + channel → picks a CSV version
3. Catalog Operator creates an InstallPlan
4. (Manual only) you approve it
5. InstallPlan creates CRDs, RBAC and the CSV
6. OLM Operator sees the CSV → creates the operator Deployment
7. CSV → Succeeded
```

---

## **12. Upgrades**

### **How upgrades are driven**

The operator author builds an **upgrade graph** in the catalog:

| Field | Meaning |
|---|---|
| `replaces` | This version upgrades directly from version X |
| `skips` | This version may also replace these versions |
| `skipRange` | Any version in this range can jump straight here |

OLM follows the graph, so you can't jump to a version that skips a required step.

### **Update flow**

```
Catalog updated with v1.3 ──▶ Subscription sees it on your channel
        │
        ▼
New InstallPlan created
        │
   Automatic?── yes ──▶ applied
        │ no
        ▼
   Wait for oc patch ... approved:true
        │
        ▼
New CSV (v1.3) → Installing → Succeeded → old CSV (v1.2) Replaced
```

### **Control updates**

```bash
# Switch channel
oc patch sub openshift-gitops-operator -n openshift-operators \
  --type merge -p '{"spec":{"channel":"gitops-1.13"}}'

# Make updates manual
oc patch sub openshift-gitops-operator -n openshift-operators \
  --type merge -p '{"spec":{"installPlanApproval":"Manual"}}'
```

> OpenShift also **blocks cluster upgrades** when an installed operator isn't compatible with the next OpenShift version (`olm.maxOpenShiftVersion`). You'll see this in Topic 16.

---

## **13. Dependency Resolution**

An operator can **require** another operator or a CRD:

```yaml
# in the bundle's dependencies.yaml
dependencies:
  - type: olm.package
    value:
      packageName: etcd
      version: ">=0.9.0 <0.10.0"
```

When you subscribe, OLM:
1. Reads the dependencies
2. Finds a matching package in the available catalogs
3. Adds extra InstallPlan steps (and Subscriptions) automatically

If it **can't** find one, the Subscription shows `ResolutionFailed`:
```bash
oc get sub my-sub -n my-ns -o jsonpath='{.status.conditions}'
```

---

## **14. Uninstalling Operators**

```bash
# 1. Delete the custom resources first (your databases, clusters...)
oc delete postgrescluster --all -n my-app

# 2. Delete the Subscription
oc delete subscription openshift-gitops-operator -n openshift-operators

# 3. Delete the CSV (this removes the operator Deployment)
oc delete csv openshift-gitops-operator.v1.12.0 -n openshift-operators
```

| Item | Deleted with the CSV? |
|---|---|
| Operator pods and RBAC | ✅ Yes |
| CRDs | ❌ No (they stay, so your data is safe) |
| Custom resources | ❌ No (they become orphaned) |
| Operands (databases, etc.) | Depends on the operator |

**Always delete the custom resources first.** Otherwise the operator is gone and nothing can clean them up.

---

## **15. OLM v1 (Next Generation)**

OLM "classic" (v0, everything above) is what most clusters run. **OLM v1** is the redesign:

| | OLM v0 (classic) | OLM v1 |
|---|---|---|
| Install object | Subscription + OperatorGroup + InstallPlan + CSV | A single **ClusterExtension** |
| Scope | Per-namespace OperatorGroups | Cluster-scoped, simpler permissions model |
| Content format | Bundles with install modes | Registry+v1 bundles (AllNamespaces model) |
| Catalogs | CatalogSource | **ClusterCatalog** |
| Controller | OLM + Catalog operators | operator-controller + catalogd |

```yaml
# OLM v1 example
apiVersion: olm.operatorframework.io/v1
kind: ClusterExtension
metadata:
  name: argocd
spec:
  namespace: argocd
  serviceAccount:
    name: argocd-installer
  source:
    sourceType: Catalog
    catalog:
      packageName: argocd-operator
      version: 0.x
```

> Know the idea now. Learn v1 properly once your cluster ships it and your team adopts it.

---

## **16. Disconnected / Air-Gapped Clusters**

Clusters with no internet cannot read Red Hat catalogs. Steps:

```
1. Mirror the catalog and operator images to a private registry   (oc-mirror)
2. Disable the default catalog sources
3. Create a CatalogSource pointing at the mirrored index image
4. Use ImageContentSourcePolicy / ImageDigestMirrorSet so image pulls are redirected
```

```bash
oc-mirror --config imageset-config.yaml docker://registry.internal:5000
```

> ❌ Not practicable in the sandbox. Know the idea for enterprise work.

---

## **17. Troubleshooting**

| Symptom | Where to look | Likely cause |
|---|---|---|
| Operator missing in OperatorHub | `oc get catalogsource -n openshift-marketplace` and catalog pods | Catalog pod down, or default sources disabled |
| Subscription stuck | `oc get sub -o yaml` → `status.conditions` | `ResolutionFailed`: wrong package, channel or catalog |
| InstallPlan not applied | `oc get ip` | `installPlanApproval: Manual` waiting for approval |
| CSV `Pending` | `oc describe csv` | Missing OperatorGroup, unsupported install mode, missing dependency |
| CSV `Failed` | `oc describe csv`, operator pod logs | Quota, image pull error, or RBAC problem |
| "Multiple OperatorGroups" error | `oc get og -n <ns>` | More than one OperatorGroup in the namespace |
| Operator pod `ImagePullBackOff` | `oc describe pod` | Mirror or pull-secret problem |
| Cluster upgrade blocked | `oc get clusterversion` | Installed operator not compatible (see Topic 16) |

### **Debug order**
```bash
oc get sub,ip,csv -n <ns>
oc describe sub <name> -n <ns>
oc get events -n <ns> --sort-by=.lastTimestamp | tail
oc logs -n openshift-operator-lifecycle-manager deploy/catalog-operator | tail     # admin
```

---

## **18. Real-World Examples**

### **Example 1: List everything installed on your cluster**

```bash
oc get csv -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase | sort -u
```

### **Example 2: Pin a production operator safely**

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: gitops-1.13            # pinned minor channel
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Manual     # a person approves each update
  startingCSV: openshift-gitops-operator.v1.13.1
```

### **Example 3: Approve a pending update**

```bash
oc get ip -n openshift-operators                       # find APPROVED=false
oc patch ip install-abc12 -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
oc get csv -n openshift-operators -w                   # watch it replace the old version
```

### **Example 4: Find which operator provides an API**

```bash
oc get csv -A -o json | jq -r '.items[] | select(.spec.customresourcedefinitions.owned[]?.kind=="Kafka") | .metadata.name'
```

---

## **19. Best Practices**

### **Catalog and channel**
- ✅ Pin a **minor channel** (`stable-1.2`) in production
- ✅ Prefer **Red Hat and certified** catalogs for production workloads
- ❌ Don't use `candidate` or `fast` in production

### **Approval**
- ✅ **Manual** approval in production, **Automatic** in dev and test
- ✅ Read the InstallPlan before approving
- ✅ Test upgrades in a non-prod cluster first

### **Namespaces and scope**
- ✅ One OperatorGroup per namespace
- ✅ Use **OwnNamespace/SingleNamespace** when you want strict isolation
- ✅ Use dedicated namespaces (not `default`) for operators

### **Operations**
- ✅ Store Subscriptions and OperatorGroups in **Git** (GitOps)
- ✅ Monitor CSV phase (alert on anything other than `Succeeded`)
- ✅ Delete custom resources **before** uninstalling the operator

---

## **20. Key Takeaways**

1. **OLM installs and updates Operators.** Operators then manage your apps.
2. **Five objects:** CatalogSource, Subscription, InstallPlan, CSV, OperatorGroup.
3. **Flow:** Catalog → Subscription → InstallPlan → CSV → operator pod.
4. **Channels** define update tracks, and **installPlanApproval** controls who approves updates.
5. **OperatorGroup** decides where an operator may watch (Own, Single, Multi, All namespaces).
6. **Uninstall = delete CRs, then Subscription, then CSV.** CRDs remain.
7. **OLM v1** (`ClusterExtension`) is the future, and classic OLM is still the majority today.

### **Common Commands**

```bash
oc get catalogsource -n openshift-marketplace
oc get packagemanifests -n openshift-marketplace
oc get og,sub,ip,csv -n <namespace>
oc describe sub <name> -n <namespace>
oc patch ip <name> -n <namespace> --type merge -p '{"spec":{"approved":true}}'
oc get csv -A
```

---

**✅ Topic 8 Complete**

When ready, reply:
- ✅ **"Ready for Topic 9"** → Move to: Deployments & Rollouts
- ❓ **"Need clarification on [section]"**
