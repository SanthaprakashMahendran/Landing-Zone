# **Topic 6: Security Context Constraints (SCC) ⭐ — Complete Notes**

---

## **Table of Contents**
1. Introduction
2. What is SCC?
3. Problems SCC Solves
4. How SCC Works
5. Types of Pre-configured SCCs
6. SCC vs Pod Security Policy vs Pod Security Standards
7. SCCs in Projects
8. SCC Components Explained
9. Granting SCCs to Users/ServiceAccounts
10. Real-World Scenarios
11. Common Problems & Solutions
12. Best Practices
13. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

**SCC (Security Context Constraints)** = OpenShift's way to control what pods are allowed to do at the system level

**Think of it like:**
```
Security Guard at a Building:
├─ Checks who enters (user)
├─ Checks what they carry (capabilities)
├─ Checks where they can go (host access)
└─ Enforces rules (SCC policies)

SCC = Security Guard for Pods
```

### **Purpose**

SCCs ensure:
- ✅ Pods don't run as root (security)
- ✅ Pods can't access host filesystem (isolation)
- ✅ Pods can't escape container (containment)
- ✅ System remains secure (by default)

---

## **2. What is SCC?**

### **Simple Explanation**

An SCC is a policy that defines:
- What users can run containers
- What those containers are allowed to do
- What system resources they can access
- What security constraints apply

### **Why SCC Exists**

**Problem:** Containers can be dangerous if not constrained
```
Unrestricted container:
├─ Runs as root user
├─ Accesses host filesystem
├─ Mounts sensitive directories
├─ Uses privileged mode
└─ Can compromise entire cluster!
```

**Solution:** SCC enforces security by default
```
Container with SCC:
├─ Runs as non-root user
├─ Cannot access host filesystem
├─ Cannot mount sensitive paths
├─ Cannot use privileged mode
└─ Cluster remains safe!
```

---

## **3. Problems SCC Solves**

### **Security Problem 1: Privilege Escalation**

**Without SCC:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: malicious-pod
spec:
  containers:
  - name: app
    image: evil-image:1.0
    securityContext:
      runAsUser: 0          # Run as root!
      privileged: true      # Privileged mode!
    # Pod runs as root with full privileges
    # Can compromise entire system!
```

**With SCC (restricted):**
```
OpenShift admission controller intercepts:
├─ Checks SCC policies
├─ Finds runAsUser: 0 is not allowed
├─ Finds privileged: true is not allowed
├─ REJECTS pod creation
└─ Pod never runs, cluster safe!
```

---

### **Security Problem 2: Host Access**

**Without SCC:**
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: app:1.0
    volumeMounts:
    - name: host-root
      mountPath: /host-root
  volumes:
  - name: host-root
    hostPath:
      path: /              # Mount entire host filesystem!
  # Pod can read all host files!
```

**With SCC (restricted):**
```
SCC restricts hostPath volumes:
├─ allowHostDirVolumePlugin: false
├─ Pod tries to use hostPath
├─ REJECTED by admission controller
└─ Pod creation fails, cluster safe!
```

---

### **Security Problem 3: Capability Escalation**

**Without SCC:**
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: app:1.0
    securityContext:
      capabilities:
        add:
        - NET_ADMIN         # Add dangerous capability
        - SYS_ADMIN
  # Pod gets dangerous Linux capabilities
  # Can compromise networking, kernel!
```

**With SCC (restricted):**
```
SCC restricts capabilities:
├─ Dangerous capabilities not allowed
├─ Pod tries to add NET_ADMIN
├─ REJECTED by SCC policy
└─ Pod cannot run with dangerous caps!
```

---

## **4. How SCC Works**

### **SCC Enforcement Process**

```
1. User creates Pod
   └─ Submits YAML to API server

2. Admission Controller Intercepts
   ├─ Checks if pod's security context valid
   ├─ Checks pod's service account
   ├─ Determines which SCC applies
   └─ Enforces SCC policies

3. SCC Policy Evaluated
   ├─ Can pod run as specified user?
   ├─ Can pod use specified capabilities?
   ├─ Can pod access host?
   ├─ Can pod use privileged mode?
   └─ All checks pass?

4. Result
   ├─ YES: Pod admitted (modified by SCC)
   └─ NO: Pod rejected, creation fails
```

---

### **SCC Admission Flow**

```
Pod submitted:
├─ runAsUser: 0 (root)
├─ privileged: true
└─ hostNetwork: true

SCC applied (restricted):
├─ Can run as root? NO
├─ Can be privileged? NO
├─ Can use host network? NO

Result: Pod REJECTED
(Security prevented it!)
```

---

### **SCC Application Priority**

When pod is created, OpenShift chooses SCC:

```
1. Service account's assigned SCCs (highest priority)
   └─ If service account has SCC, use it

2. Project defaults
   └─ If project specifies default SCC

3. Global default (restricted)
   └─ Default for all pods if nothing specified

Result: Pod runs under chosen SCC constraints
```

---

## **5. Types of Pre-configured SCCs**

OpenShift provides three pre-configured SCCs:

### **SCC 1: restricted (Default, Most Secure)**

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: restricted
spec:
  allowHostDirVolumePlugin: false       # NO host paths
  allowHostIPC: false                   # NO host IPC
  allowHostNetwork: false               # NO host networking
  allowHostPID: false                   # NO host PID namespace
  allowHostPorts: false                 # NO host ports
  allowPrivilegedContainer: false       # NO privileged containers
  allowedCapabilities: []               # NO extra capabilities
  allowedFlexVolumes: []
  allowedUnsafeSysctls: []
  defaultAddCapabilities: []            # NO default caps
  fsGroup:
    type: MustRunAs
    ranges:
    - min: 1
      max: 65535
  readOnlyRootFilesystem: false         # RootFS writable
  requiredDropCapabilities:
  - KILL
  - SETUID
  - SETGID
  runAsUser:
    type: MustRunAsNonRoot              # MUST be non-root!
  seLinuxContext:
    type: MustRunAs
  supplementalGroups:
    type: MustRunAs
  volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
```

**Use when:** Regular applications, microservices, web apps
**Security level:** ✅ MOST SECURE

**What's allowed:**
```
✅ Non-root user
✅ Regular volumes (PVC, configMap, secret)
✅ Limited Linux capabilities
✅ SELinux enforced
✅ No host access

❌ Root user
❌ Privileged mode
❌ Host paths
❌ Host networking
```

---

### **SCC 2: baseline (Medium Security)**

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: baseline
spec:
  allowHostDirVolumePlugin: false
  allowHostIPC: true                    # HOST IPC allowed
  allowHostNetwork: true                # HOST networking allowed
  allowHostPID: true                    # HOST PID allowed
  allowHostPorts: true                  # HOST ports allowed
  allowPrivilegedContainer: false       # NO privileged
  allowedCapabilities: []
  defaultAddCapabilities: []
  fsGroup:
    type: RunAsAny                      # Any fsGroup
  readOnlyRootFilesystem: false
  requiredDropCapabilities:
  - KILL
  - SETUID
  - SETGID
  runAsUser:
    type: RunAsAny                      # Can be any user
  seLinuxContext:
    type: RunAsAny                      # SELinux not enforced
  volumes:
  - '*'
```

**Use when:** Applications needing some host access
**Security level:** ⚠️ MEDIUM SECURITY

**What's allowed:**
```
✅ Host IPC
✅ Host networking
✅ Host PID namespace
✅ Host ports
✅ More capabilities
✅ Any user (including root)

❌ Privileged mode
❌ Root access to host
```

---

### **SCC 3: privileged (Least Secure)**

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: privileged
spec:
  allowHostDirVolumePlugin: true        # HOST paths allowed!
  allowHostIPC: true                    # HOST IPC allowed
  allowHostNetwork: true                # HOST networking allowed
  allowHostPID: true                    # HOST PID allowed
  allowHostPorts: true                  # HOST ports allowed
  allowPrivilegedContainer: true        # PRIVILEGED allowed!
  allowedCapabilities:
  - '*'                                 # ALL capabilities!
  defaultAddCapabilities: []
  fsGroup:
    type: RunAsAny
  readOnlyRootFilesystem: false
  runAsUser:
    type: RunAsAny                      # Can be root!
  seLinuxContext:
    type: RunAsAny                      # SELinux disabled
  volumes:
  - '*'                                 # All volume types
```

**Use when:** System pods, monitoring agents, infrastructure
**Security level:** ❌ LEAST SECURE

**What's allowed:**
```
✅ EVERYTHING!
✅ Run as root
✅ Privileged mode
✅ Host filesystem access
✅ Host IPC/networking/PID
✅ All Linux capabilities
✅ All volume types

Only use when absolutely necessary!
```

---

### **Comparison of SCCs**

| Feature | restricted | baseline | privileged |
|---------|---|---|---|
| **Root user** | ❌ No | ⚠️ Yes | ✅ Yes |
| **Privileged mode** | ❌ No | ❌ No | ✅ Yes |
| **Host filesystem** | ❌ No | ❌ No | ✅ Yes |
| **Host networking** | ❌ No | ✅ Yes | ✅ Yes |
| **Host IPC** | ❌ No | ✅ Yes | ✅ Yes |
| **Host ports** | ❌ No | ✅ Yes | ✅ Yes |
| **Capabilities** | Limited | ⚠️ More | ✅ All |
| **SELinux** | Enforced | ⚠️ Any | ⚠️ Any |
| **Security level** | 🏆 Best | ⚠️ Medium | ❌ Weakest |

---

## **6. SCC vs Pod Security Policy vs Pod Security Standards**

### **Complete Comparison**

| Aspect | Pod Security Policy | SCC | Pod Security Standards |
|--------|---|---|---|
| **Kubernetes version** | v1.14-v1.24 | N/A (OpenShift only) | v1.23+ (beta), v1.25+ (stable) |
| **Status** | ❌ Deprecated | ✅ Active | ✅ New standard |
| **Platform** | Kubernetes | OpenShift | Kubernetes (all) |
| **Granularity** | Basic | ✅ Fine-grained | Basic |
| **Flexibility** | Limited | ✅ Highly customizable | Limited |
| **Default enforcement** | ⚠️ Optional | ✅ Always enforced | ✅ Always enforced |
| **Ease of use** | Medium | ⚠️ Complex | ✅ Simple |
| **Maintenance** | ❌ No longer updated | ✅ Actively maintained | ✅ Actively developed |

---

### **When to Use Each**

```
Kubernetes (vanilla):
└─ Use Pod Security Standards (new way)
   (Pod Security Policy is deprecated)

OpenShift:
└─ Use SCC (best for OpenShift)
   (Most powerful, most granular)

Cross-platform:
└─ Use Pod Security Standards (portable)
   (Works on any Kubernetes cluster)
```

---

## **7. SCCs in Projects**

### **Default SCC Applied**

When you create a pod in a project:

```bash
oc new-project my-app
# All pods in my-app use default SCC

oc run myapp --image=myapp:1.0
# This pod gets 'restricted' SCC automatically
```

**Flow:**
```
1. Pod created in project
2. OpenShift checks pod's service account
3. If no specific SCC granted, use default
4. Default is 'restricted' SCC
5. Pod security context modified by SCC
6. Pod runs with restrictions
```

---

### **View Available SCCs**

```bash
# List all SCCs in cluster
oc get scc

# Output:
# NAME           PRIV    CAPS   SELINUX   RUNASUSER   FSGROUP    READONLYROOT
# anyuid         false   []     MustRunAs RunAsAny    RunAsAny   false
# hostaccess     false   []     MustRunAs MustRunAs   MustRunAs  false
# hostmount-anyuid false  []     MustRunAs RunAsAny    RunAsAny   false
# hostnetwork    false   []     MustRunAs MustRunAs   MustRunAs  false
# nonroot        false   []     MustRunAs MustRunAsNonRoot MustRunAs false
# privileged     true    [*]    RunAsAny  RunAsAny    RunAsAny   false
# restricted     false   []     MustRunAs MustRunAsNonRoot MustRunAs false
# restricted-v2  false   []     MustRunAs MustRunAsNonRoot MustRunAs false
```

---

### **Describe SCC**

```bash
# Show all details of restricted SCC
oc describe scc restricted

# Output:
# Name:                     restricted
# Priority:                 <none>
# Access:
#   Users:                  system:authenticated
#   Groups:                 system:serviceaccounts
# Allow Privileged:         false
# Allow Host Directories:   false
# Allow Host IPC:           false
# Allow Host Network:       false
# Allow Host Ports:         false
# Allow Host PID:           false
# Allow Privileged Escalation: false
# Capabilities:             <none>
# Default Add Capabilities: <none>
# Required Drop Capabilities: KILL,SETUID,SETGID
# Read Only Root Filesystem: false
# Run As User Strategy: MustRunAsNonRoot
# UID: <none>
# Supplemental Groups Strategy: MustRunAs
# Ranges: 1-65535
# FSGroup Strategy: MustRunAs
# Ranges: 1-65535
# SELinux Context Strategy: MustRunAs
# SELinux Ranges: <none>
# Allowed Volume Types: configMap,downwardAPI,emptyDir,persistentVolumeClaim,projected,secret
```

---

### **View SCC for Specific Pod**

```bash
# See which SCC a pod uses
oc get pod myapp -o yaml | grep openshift.io/scc

# Output:
# openshift.io/scc: restricted
```

---

## **8. SCC Components Explained**

### **runAsUser (Who the container runs as)**

```yaml
runAsUser:
  type: MustRunAsNonRoot    # Options:
  # MustRunAsNonRoot: CANNOT be root
  # MustRunAs: MUST use specific UID/range
  # RunAsAny: Can be any UID
  ranges:
  - min: 1
    max: 65535
```

**Meaning:**
```
MustRunAsNonRoot:
└─ Pod MUST run as non-root user
   (Any UID from 1-65535)

MustRunAs:
└─ Pod MUST use specific UID/range
   (Cannot choose its own)

RunAsAny:
└─ Pod can be any UID
   (Including root: 0)
```

---

### **fsGroup (File system group)**

```yaml
fsGroup:
  type: MustRunAs      # Options:
  # MustRunAs: MUST use specific range
  # RunAsAny: Can be any group
  ranges:
  - min: 1
    max: 65535
```

---

### **allowPrivilegedContainer (Privileged mode)**

```yaml
allowPrivilegedContainer: false   # true/false
```

**Meaning:**
```
false (restricted):
└─ Pod CANNOT run in privileged mode
   (Cannot access host kernel directly)

true (privileged):
└─ Pod CAN run in privileged mode
   (Can access host kernel)
```

---

### **allowHostDirVolumePlugin (Host filesystem access)**

```yaml
allowHostDirVolumePlugin: false   # true/false
```

**Meaning:**
```
false (restricted):
└─ Pod CANNOT mount host directories
   (Cannot read/write host filesystem)

true (privileged):
└─ Pod CAN mount host directories
   (Can access entire host filesystem)
```

---

### **allowHostNetwork (Host networking)**

```yaml
allowHostNetwork: false   # true/false
```

**Meaning:**
```
false (restricted):
└─ Pod uses CNI network
   (Isolated from host networking)

true (privileged):
└─ Pod uses host networking
   (Can sniff traffic, affect host network)
```

---

### **allowedCapabilities (Linux capabilities)**

```yaml
allowedCapabilities: []        # Empty = no extra capabilities
# or
allowedCapabilities:
- NET_ADMIN                    # Allow specific capability
- SYS_TIME
# or
allowedCapabilities:
- '*'                          # Allow ALL capabilities
```

**Linux capabilities:**
```
NET_ADMIN: Network administration (dangerous!)
SYS_ADMIN: System administration (very dangerous!)
SYS_TIME: Set system time
NET_RAW: Raw socket access
...and many more
```

---

## **9. Granting SCCs to Users/ServiceAccounts**

### **Grant SCC to Service Account**

```bash
# Grant SCC to service account
oc adm policy add-scc-to-user <scc-name> -z <service-account> -n <namespace>

# Examples:
oc adm policy add-scc-to-user privileged -z myapp-sa -n my-app
oc adm policy add-scc-to-user anyuid -z monitoring-sa -n monitoring
oc adm policy add-scc-to-user restricted -z default -n default
```

---

### **Grant SCC to User**

```bash
# Grant SCC to user (not service account)
oc adm policy add-scc-to-user <scc-name> <username>

# Example:
oc adm policy add-scc-to-user privileged developer-user
```

---

### **Grant SCC to Group**

```bash
# Grant SCC to group
oc adm policy add-scc-to-group <scc-name> <groupname>

# Example:
oc adm policy add-scc-to-group restricted system:serviceaccounts:default
```

---

### **View SCC Permissions**

```bash
# Check who can use specific SCC
oc get scc restricted -o yaml | grep -A 10 "Users:"

# Or describe
oc describe scc restricted | grep -A 5 "Access:"
```

---

### **Remove SCC from Service Account**

```bash
# Remove SCC
oc adm policy remove-scc-from-user <scc-name> -z <service-account> -n <namespace>

# Example:
oc adm policy remove-scc-from-user privileged -z myapp-sa -n my-app
```

---

## **10. Real-World Scenarios**

### **Scenario 1: Regular Web Application**

**App:** Node.js web server
**Requirements:** None special
**SCC:** restricted (default)

```bash
# Deploy normally
oc create deployment myapp --image=node:16

# Pod automatically gets 'restricted' SCC
# Pod runs as non-root
# Cannot access host
# Secure by default!
```

---

### **Scenario 2: Database Pod**

**App:** PostgreSQL database
**Requirements:** Needs to write to filesystem
**SCC:** restricted (with volumes)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:13
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data

# Uses 'restricted' SCC
# Has PVC (allowed volume type)
# Runs as postgres user (non-root)
# Secure!
```

---

### **Scenario 3: Monitoring Agent (Needs Host Access)**

**App:** Prometheus node exporter
**Requirements:** Access to host metrics
**SCC:** Need custom or privileged

**Step 1: Create service account**
```bash
oc create serviceaccount prometheus-sa -n monitoring
```

**Step 2: Grant privileged SCC**
```bash
oc adm policy add-scc-to-user privileged -z prometheus-sa -n monitoring
```

**Step 3: Deploy with service account**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: prometheus-node-exporter
  namespace: monitoring
spec:
  template:
    spec:
      serviceAccountName: prometheus-sa
      hostNetwork: true
      hostPID: true
      containers:
      - name: exporter
        image: prometheus/node-exporter:latest

# Uses 'privileged' SCC (granted to service account)
# Can access host metrics
# Runs on every node
```

---

### **Scenario 4: Multi-tier Application**

**Apps:**
- Frontend (web): Node.js
- Backend (API): Go
- Database: PostgreSQL
- Cache: Redis
- Monitoring: Prometheus

**SCC Assignment:**
```
Frontend:    restricted (default)     ✅ Secure
Backend:     restricted (default)     ✅ Secure
Database:    restricted + PVC         ✅ Secure
Cache:       restricted + PVC         ✅ Secure
Monitoring:  privileged (special)     ⚠️ Only when needed
```

---

## **11. Common Problems & Solutions**

### **Problem 1: Pod Rejected - Violates SCC**

**Error:**
```
Error creating pod:
Pod violates restricted SCC:
allowPrivilegedContainer=true not allowed
```

**Cause:**
```
Pod spec has:
securityContext:
  privileged: true

restricted SCC doesn't allow it
```

**Solution:**
```bash
# Option 1: Remove privileged from pod spec
# (Best if possible)

# Option 2: Grant SCC to service account
oc adm policy add-scc-to-user privileged -z service-account-name

# Option 3: Use different SCC
# Create custom SCC allowing what pod needs
```

---

### **Problem 2: Pod Can't Write Files**

**Error:**
```
Permission denied writing to /app/logs
```

**Cause:**
```
Pod runs as non-root user
File permissions don't allow it
```

**Solution:**
```yaml
# Use emptyDir volume for writable path
volumeMounts:
- name: logs
  mountPath: /app/logs
volumes:
- name: logs
  emptyDir: {}

# Now pod can write to /app/logs
```

---

### **Problem 3: Pod Needs To Run as Root**

**Error:**
```
Application requires root user
restricted SCC prevents it
```

**Solution:**
```bash
# Create service account
oc create serviceaccount myapp-sa

# Grant SCC allowing root
oc adm policy add-scc-to-user anyuid -z myapp-sa

# Deploy with service account
oc create deployment myapp \
  --image=myapp \
  --overrides='{"spec":{"template":{"spec":{"serviceAccountName":"myapp-sa"}}}}'
```

---

### **Problem 4: Pod Needs Host Path Access**

**Error:**
```
hostPath volumes not allowed by restricted SCC
```

**Solution:**
```bash
# Grant hostaccess or privileged SCC
oc adm policy add-scc-to-user hostaccess -z myapp-sa

# Now pod can mount host paths
```

---

## **12. Best Practices**

### **SCC Assignment Best Practices**

```
1. Use most restrictive SCC possible
   └─ Start with 'restricted'
   └─ Only escalate if needed

2. Never use 'privileged' by default
   └─ Only for system components
   └─ Only when necessary

3. Document why pod needs SCC
   └─ Why does it need privileges?
   └─ What specifically does it need?

4. Audit SCC assignments regularly
   └─ Review who has what SCC
   └─ Remove unnecessary privileges
```

---

### **Security Decision Tree**

```
Does pod need special security?
│
├─ No (regular web app)
│  └─ Use 'restricted' (default)
│     → Most secure
│
├─ Yes, why?
│  │
│  ├─ Needs host metrics?
│  │  └─ Use 'hostaccess' or 'privileged'
│  │
│  ├─ Needs run as specific user?
│  │  └─ Use 'anyuid'
│  │
│  ├─ Needs host networking?
│  │  └─ Use 'hostnetwork'
│  │
│  └─ Needs privileged mode?
│     └─ Use 'privileged'
│        ⚠️ Only if absolutely necessary
```

---

### **Audit SCCs**

```bash
# Who has privileged SCC?
oc get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="privileged")'

# Review all SCC assignments
oc get scc -o json | jq '.items[] | {name: .metadata.name, users: .users}'

# Check specific service account
oc get serviceaccount myapp-sa -o yaml | grep -A 5 "secrets:"
```

---

## **13. Key Takeaways**

### **What SCC Does**

```
SCC Controls:
├─ Who can run containers (user/UID)
├─ What capabilities containers get
├─ What host resources pods can access
├─ Whether privileged mode allowed
├─ What volumes pods can use
├─ Whether root access allowed
└─ And much more!

Result:
✅ Pods secure by default
✅ Cluster protected from malicious workloads
✅ System pods get needed permissions
✅ Fine-grained control per service account
```

---

### **SCC Types at a Glance**

```
restricted (Default)
├─ Most secure
├─ Non-root only
├─ No host access
├─ Use for: Regular applications
└─ Security: ✅ BEST

baseline
├─ Medium security
├─ Host IPC/networking allowed
├─ No privileged mode
├─ Use for: Apps needing some host access
└─ Security: ⚠️ MEDIUM

privileged
├─ Least secure
├─ Everything allowed
├─ Root allowed
├─ Use for: System pods, monitoring agents
└─ Security: ❌ WEAKEST (but sometimes needed)
```

---

### **SCC Workflow**

```
1. Pod submitted
   ↓
2. SCC enforcement begins
   ├─ Check pod's service account
   ├─ Check pod's security context
   └─ Determine applicable SCC
   ↓
3. SCC policy evaluated
   ├─ Is runAsUser allowed?
   ├─ Are capabilities allowed?
   ├─ Is host access allowed?
   └─ Is everything allowed?
   ↓
4. Result
   ├─ YES: Pod admitted (modified by SCC)
   └─ NO: Pod rejected, creation fails

Security by default!
```

---

### **Common Commands Reference**

```bash
# View SCCs
oc get scc
oc describe scc restricted
oc get scc -o yaml

# Grant/remove SCCs
oc adm policy add-scc-to-user privileged -z myapp-sa -n my-app
oc adm policy remove-scc-from-user privileged -z myapp-sa -n my-app
oc adm policy add-scc-to-group restricted system:authenticated

# Check pod's SCC
oc get pod myapp -o yaml | grep openshift.io/scc

# View SCC permissions
oc describe scc privileged | grep -A 5 "Users:"

# Create custom SCC
oc apply -f custom-scc.yaml
```

---

### **When to Use Each SCC**

```
restricted → Regular applications (web, API, services)
baseline → Apps needing some host access
anyuid → Apps requiring specific non-root user
hostaccess → System components needing host FS
hostnetwork → Network components needing host network
hostmount-anyuid → NFS/mount components
privileged → System pods, monitoring agents

Default: restricted (most secure)
```

---

**✅ Topic 6 Complete**

When ready, reply:
- ✅ **"Ready for Topic 7"** → Move to: OpenShift Operators & OperatorHub ⭐
- ❓ **"Need clarification on [section]"** — Ask about specific parts
