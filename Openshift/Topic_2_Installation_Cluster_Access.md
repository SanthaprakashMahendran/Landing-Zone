# **Topic 2: OpenShift Installation & Cluster Access — Complete Notes**

> **Sandbox practicability:** Partly. Access topics (console, `oc login`, tokens, kubeconfig) are ✅ hands-on.
> Installation topics (IPI/UPI/ROSA create) are ❌ theory only — the sandbox cluster already exists.

---

## **Table of Contents**
1. Introduction
2. OpenShift Flavors (Where Clusters Come From)
3. Installation Methods (Theory)
4. ROSA Specifics
5. Cluster Access: Web Console
6. Cluster Access: oc CLI Login
7. Tokens, Contexts & kubeconfig
8. Service Account Tokens
9. Inspecting the Cluster
10. Hands-on Lab (Sandbox)
11. Troubleshooting
12. Key Takeaways

---

## **1. Introduction**

With vanilla Kubernetes you pick an installer (kubeadm, kops, EKS...) and then get a kubeconfig with a client certificate or cloud IAM token.

With OpenShift:
- The **installer provisions the OS, the control plane and the cluster operators together**. Nodes run Red Hat CoreOS (RHCOS), which is immutable and managed by the cluster itself.
- Access goes through a **built-in OAuth server**, not client certificates (except the installer's break-glass admin kubeconfig).
- The console and `oc` both authenticate through that OAuth server and get a **bearer token**.

```
User ──login──▶ OAuth Server ──token──▶ API Server ──▶ RBAC check ──▶ Resource
 (console / oc)   (openshift-authentication)   (sha256~xxxx token)
```

---

## **2. OpenShift Flavors (Where Clusters Come From)**

| Flavor | Who runs the control plane | Where | Notes |
|---|---|---|---|
| **OKD** | You | Anywhere | Community upstream, no Red Hat support |
| **OpenShift Container Platform (OCP)** | You | On-prem, any cloud | Self-managed, you handle upgrades |
| **ROSA** (Red Hat OpenShift Service on AWS) | Red Hat + AWS SRE | AWS | Managed. **Your sandbox console says this.** |
| **ARO** | Microsoft + Red Hat | Azure | Managed |
| **OpenShift Dedicated** | Red Hat SRE | AWS / GCP | Managed |
| **OpenShift Local (CRC)** | You | Your laptop | Single-node, good for learning offline |
| **Developer Sandbox** | Red Hat | Red Hat-hosted | Free, shared, restricted permissions |

ROSA has two architectures:
- **ROSA Classic**: control plane runs in *your* AWS account.
- **ROSA HCP** (Hosted Control Plane): control plane runs in *Red Hat's* account, and only worker nodes run in yours. This is the default today.

---

## **3. Installation Methods (Theory)**

### **3.1 Installer-Provisioned Infrastructure (IPI)**

The `openshift-install` binary creates the VMs, load balancers, DNS, storage and networks itself, using your cloud credentials.

```bash
openshift-install create install-config   # prompts for platform, region, pull secret
openshift-install create cluster          # ~40 min
# output: auth/kubeconfig and auth/kubeadmin-password
```

### **3.2 User-Provisioned Infrastructure (UPI)**

You create the VMs, networks, load balancers and DNS yourself. The installer only produces ignition configs. Use it when a company's rules or air-gapped networks prevent IPI.

### **3.3 Assisted Installer / Agent-based Installer**

Boot nodes from a discovery ISO, and a web UI or agent drives the install. Common for **bare metal** and **disconnected** environments.

### **3.4 Comparison**

| | IPI | UPI | Assisted / Agent |
|---|---|---|---|
| Infra created by | Installer | You | You (boot ISO) |
| Effort | Low | High | Medium |
| Flexibility | Medium | High | Medium |
| Typical use | Cloud | Custom / restricted | Bare metal, edge |

### **3.5 What the installer actually does**

```
1. Bootstrap node boots, starts a temporary control plane
2. Real control-plane (master) nodes join and take over
3. Bootstrap node is removed
4. Cluster Version Operator rolls out all Cluster Operators
5. Workers join, ingress/registry/console come up
```

> ❌ **Sandbox:** none of this can be run. Know the flow; don't try it.

---

## **4. ROSA Specifics**

### **4.1 Prerequisites (for your own future cluster)**
- AWS account with the **ROSA service enabled** (via the AWS console).
- Red Hat account, and the `rosa` CLI logged in with `rosa login`.
- IAM account roles and operator roles (**STS**, no long-lived keys).
- A VPC (or let the CLI create one).

### **4.2 Typical flow**

```bash
rosa login --token=<token-from-console.redhat.com>
rosa create account-roles --mode auto
rosa create cluster --cluster-name demo --sts --hosted-cp \
    --region ap-south-1 --subnet-ids subnet-a,subnet-b
rosa describe cluster -c demo
rosa create admin -c demo          # creates a cluster-admin with a generated password
```

### **4.3 Cost warning**
ROSA bills **per hour** (a service fee per vCPU plus EC2, EBS and data transfer). Practice on the sandbox, and read the pricing page before creating your own cluster. Delete it with `rosa delete cluster -c demo` when done.

> ❌ **Sandbox:** `rosa` commands are not usable, so treat this as reading.

---

## **5. Cluster Access: Web Console**

The URL pattern is:

```
https://console-openshift-console.apps.<cluster-domain>
```

Yours: `console-openshift-console.apps.rm1.0a51.p1.openshiftapps.com`

Two perspectives (the dropdown at the top left, showing "Core platform" in your screenshot):

| Perspective | Use |
|---|---|
| **Administrator / Core platform** | Workloads, Networking, Storage, Operators, Administration |
| **Developer** | Topology view, +Add, Builds, Pipelines, Observe |

Useful console features:
- The **`>_` icon** (top bar) opens a web terminal when the Web Terminal operator is installed.
- The **user menu → Copy login command** gives you the `oc login` command with a token.
- The **`+` icon** opens the **Import YAML** editor.

> ✅ **Sandbox:** all of it.

---

## **6. Cluster Access: oc CLI Login**

### **6.1 Install `oc` (macOS)**

```bash
brew install openshift-cli
oc version --client
```

Or download from the console: **`?` icon → Command line tools**.

### **6.2 Token login (most common)**

1. Console → user menu (top right, "santha") → **Copy login command**
2. Click **Display Token**
3. Paste:

```bash
oc login --token=sha256~xxxxxxxx --server=https://api.rm1.0a51.p1.openshiftapps.com:443
```

### **6.3 Browser login**

```bash
oc login --web --server=https://api.<cluster-domain>:443
```

### **6.4 Username / password** (only if a password-based identity provider exists)

```bash
oc login -u santha -p '<password>' --server=https://api.<cluster-domain>:443
```

### **6.5 Verify**

```bash
oc whoami               # user name
oc whoami --show-server # API URL
oc whoami --show-token  # current token (treat as a password)
oc whoami --show-console
oc project              # current project
```

### **6.6 Where the login is stored**

`oc login` writes to `~/.kube/config` (same file `kubectl` uses), so **kubectl also works** after `oc login`.

---

## **7. Tokens, Contexts & kubeconfig**

### **7.1 Token facts**
- Tokens are OAuth access tokens like `sha256~...`, **not** JWTs.
- Default lifetime is **24 hours** (`accessTokenMaxAgeSeconds: 86400`), then you log in again.
- A token is stored server side as an `OAuthAccessToken` object. Deleting it logs you out everywhere.

```bash
oc logout   # removes the token from kubeconfig
```

### **7.2 Contexts**

A context = cluster + user + namespace. `oc login` creates one named like `project/api-server:port/user`.

```bash
oc config get-contexts
oc config use-context <name>
oc config current-context
oc config view --minify
```

### **7.3 Multiple clusters**

```bash
KUBECONFIG=~/.kube/sandbox oc login ...   # separate file per cluster
export KUBECONFIG=~/.kube/sandbox
```

### **7.4 Installer admin kubeconfig (self-managed only)**

`auth/kubeconfig` from the installer contains a client certificate for `system:admin`. This is **break-glass access**, so store it safely. ROSA has no such file; use `rosa create admin` instead.

---

## **8. Service Account Tokens**

For scripts and CI, use a **service account**, not your personal token.

```bash
oc create serviceaccount ci-bot
oc policy add-role-to-user edit -z ci-bot      # grant 'edit' in this project
oc create token ci-bot --duration=1h           # short-lived token (recommended)
```

Use it:

```bash
oc login --token=<sa-token> --server=https://api.<cluster-domain>:443
oc whoami    # system:serviceaccount:santha-dev:ci-bot
```

Notes:
- Since OpenShift 4.11, long-lived secret-based SA tokens are no longer auto-created. Use `oc create token`.
- Pods get a projected token automatically at `/var/run/secrets/kubernetes.io/serviceaccount/token`.

---

## **9. Inspecting the Cluster**

```bash
oc version                         # client + server + OpenShift version
oc get clusterversion              # cluster version and upgrade state
oc get infrastructure cluster -o yaml
oc get nodes                       # may be forbidden for you
oc get clusteroperators            # health of all platform components
oc api-resources | head -50        # CRDs incl. routes, projects, builds
oc cluster-info
oc status                          # summary of the current project
```

Your permissions decide what works. Check instead of guessing:

```bash
oc auth can-i get nodes
oc auth can-i create clusterrole
oc auth can-i --list -n santha-dev
```

---

## **10. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be denied (that's a lesson too) · ❌ read only

| # | Task | Status |
|---|---|---|
| 1 | Open the console and switch between Core platform and Developer perspectives | ✅ |
| 2 | Install `oc` with `brew install openshift-cli` | ✅ |
| 3 | Copy the login command and log in from your Mac | ✅ |
| 4 | Run `oc whoami`, `oc whoami --show-server`, `oc project` | ✅ |
| 5 | Run `oc config get-contexts` and read `~/.kube/config` (the token is a secret, don't share it) | ✅ |
| 6 | Run `oc version` and note the OpenShift and Kubernetes versions | ✅ |
| 7 | Run `oc get clusterversion` and `oc get clusteroperators` | ⚠️ |
| 8 | Run `oc get nodes` and `oc get infrastructure cluster` | ⚠️ |
| 9 | Run `oc auth can-i --list -n santha-dev` and note what you can do | ✅ |
| 10 | Create SA `ci-bot`, grant `view`, create a token, log in with it, and try to create something (it should fail) | ✅ |
| 11 | Run `oc logout`, then log back in with `oc login --web` | ✅ |
| 12 | Read `rosa create cluster` help from the docs, no execution | ❌ |

### **Expected learning outcomes**
- You can log in from the CLI and know where the credentials live.
- You can tell what your sandbox account is and isn't allowed to do.
- You know why tokens expire and how to use SA tokens for automation.

---

## **11. Troubleshooting**

| Symptom | Cause | Fix |
|---|---|---|
| `error: You must be logged in to the server (Unauthorized)` | Token expired (24h) | Copy a new login command |
| `x509: certificate signed by unknown authority` | Self-signed API cert | Fine for sandbox: `--insecure-skip-tls-verify`. Avoid in production |
| `Forbidden: User "santha" cannot list nodes` | Namespace-scoped permissions | Expected; use `oc auth can-i` |
| `oc: command not found` | CLI not installed | `brew install openshift-cli` |
| Wrong cluster after login | Multiple contexts | `oc config use-context ...` |
| Login URL points to the console, not the API | Used the wrong URL | Use `https://api.<domain>:443` |

---

## **12. Key Takeaways**

1. **OCP** is self-managed, **ROSA/ARO/OSD** are managed. Your sandbox is ROSA-style.
2. Installation is **IPI** (installer builds infra), **UPI** (you build), or **Assisted/Agent** (bare metal).
3. Access is through the built-in **OAuth server**, which issues bearer tokens valid for about 24 hours.
4. `oc login` writes to the same `~/.kube/config` as kubectl.
5. Use **service accounts and `oc create token`** for automation, never your own token.
6. `oc auth can-i` tells you exactly what your user can do.

### **Topic 2 Complete ✅**
**Next: Topic 3 (already written) → Topic 4 → ... → Topic 8: OLM**
