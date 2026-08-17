# **Topic 4: Projects — OpenShift's Enhanced Namespaces — Complete Notes**

---

## **Table of Contents**
1. Introduction
2. What is a Project?
3. Projects vs Kubernetes Namespaces
4. What Gets Created with a Project?
5. RBAC in Projects
6. Resource Quotas
7. LimitRange (Default Resource Limits)
8. Network Policies
9. Managing Projects
10. Real-World Scenarios
11. Project Best Practices
12. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

**Project** = OpenShift's way of organizing and isolating resources within a cluster

**Think of it like:**
```
Kubernetes Namespace:     Basic isolation
OpenShift Project:        Namespace + Security + Quotas + Policies + RBAC
```

**Project = Namespace with superpowers**

---

## **2. What is a Project?**

### **Simple Explanation**

A Project is a logical grouping of resources in an OpenShift cluster with:
- Resource isolation (pods can't cross projects)
- Access control (RBAC built-in)
- Resource limits (quotas and limits)
- Security policies (network policies, pod security)
- Pre-configured defaults (everything ready to use)

### **Why Projects Exist**

**Problem:** Kubernetes namespaces require manual setup
```
kubectl create namespace my-app
# Now you have to manually:
├─ Create service accounts
├─ Configure RBAC roles
├─ Set up resource quotas
├─ Create network policies
├─ Set limit ranges
└─ Takes 1-2 hours!
```

**Solution:** OpenShift Projects
```
oc new-project my-app
# Everything configured automatically
# Ready to use in 1 minute!
```

### **Project Use Cases**

```
1. Multi-team environments
   ├─ Each team gets a project
   ├─ Resources isolated
   ├─ No interference
   └─ Fair resource distribution

2. Multi-environment setup
   ├─ dev project (small resources)
   ├─ staging project (medium resources)
   ├─ production project (large resources)
   └─ Easy promotion between environments

3. Billing/Cost allocation
   ├─ Project A costs tracked
   ├─ Project B costs tracked
   ├─ Easy to bill teams
   └─ Resource usage visible

4. Security/Compliance
   ├─ Project isolation enforced
   ├─ Network policies applied
   ├─ RBAC configured
   ├─ Audit trails available
   └─ Compliance requirements met
```

---

## **3. Projects vs Kubernetes Namespaces**

### **Kubernetes Namespace (Manual Everything)**

**What you get:**
```bash
kubectl create namespace my-app

Result:
├─ Just a namespace (isolation boundary)
└─ That's it!
```

**What you DON'T get (manual setup needed):**
```
❌ Service accounts
❌ RBAC roles and bindings
❌ Resource quotas
❌ Network policies
❌ Limit ranges
❌ Security context constraints
❌ Pod security policies
```

**Setup time:** 1-2 hours (lots of manual YAML)

---

### **OpenShift Project (Automatic Everything)**

**What you get:**
```bash
oc new-project my-app

Result:
├─ Namespace: my-app
├─ Service Accounts: default, builder, deployer (auto-created)
├─ RBAC Role Bindings: Users have edit role (pre-bound)
├─ Network Policies: Isolation configured (automatically)
├─ ResourceQuota: Prevents resource hogging (pre-created)
├─ LimitRange: Default pod limits (automatically applied)
├─ Security Defaults: Pod security policies applied
└─ Everything ready to go!
```

**Setup time:** 1 minute (fully automated)

---

### **Side-by-Side Comparison**

| Feature | Kubernetes Namespace | OpenShift Project |
|---------|-----|-----|
| **Isolation** | Basic isolation | ✅ Complete isolation |
| **Service Accounts** | Manual creation | ✅ Auto-created (3 defaults) |
| **RBAC Setup** | Manual (complex) | ✅ Pre-configured |
| **Resource Quotas** | Manual YAML needed | ✅ Auto-created |
| **Resource Limits** | Manual LimitRange | ✅ Auto-created |
| **Network Policies** | Manual (if any) | ✅ Default deny-all |
| **Pod Security** | Manual setup | ✅ Default policies applied |
| **Time to setup** | 1-2 hours | ✅ 1 minute |
| **Production ready?** | ❌ Needs work | ✅ Ready immediately |
| **Security defaults?** | ❌ Minimal | ✅ Secure by default |
| **Multi-team ready?** | ❌ Not ideal | ✅ Perfect |
| **Cost tracking?** | ⚠️ Possible but manual | ✅ Built-in labels |

---

## **4. What Gets Created with a Project?**

When you run `oc new-project my-app`, OpenShift automatically creates:

### **4.1 Namespace**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    # Labels for categorization
    environment: development
    owner: team-a
```

**Purpose:** Kubernetes namespace (basic isolation)

---

### **4.2 Service Accounts (3 Defaults)**

OpenShift creates three service accounts for different purposes:

**1. default Service Account**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: my-app
```
**Purpose:** Used by general pods to authenticate with API server

**2. builder Service Account**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: builder
  namespace: my-app
```
**Purpose:** Used by build pods (S2I builds, Docker builds)

**3. deployer Service Account**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployer
  namespace: my-app
```
**Purpose:** Used by deployment processes

**Why three accounts?**
- **Separation of concerns:** Each process has minimal permissions needed
- **Security:** If one is compromised, others are not affected
- **Auditability:** Can track which service account performed an action

---

### **4.3 RBAC Role Bindings (Pre-configured)**

OpenShift automatically binds roles to service accounts and users:

**RoleBindings created:**

```yaml
# 1. default user gets 'edit' role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edit
  namespace: my-app
subjects:
- kind: User
  name: your-username
roleRef:
  kind: ClusterRole
  name: edit

# 2. builder service account gets build permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: system:build-strategy-source
  namespace: my-app
subjects:
- kind: ServiceAccount
  name: builder
  namespace: my-app
roleRef:
  kind: ClusterRole
  name: system:build-strategy-source

# 3. deployer gets deployment permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: system:deployer
  namespace: my-app
subjects:
- kind: ServiceAccount
  name: deployer
  namespace: my-app
roleRef:
  kind: ClusterRole
  name: system:deployer
```

**What permissions does 'edit' role have?**
```
Can do:
✅ Create pods
✅ Create services
✅ Create deployments
✅ Create routes
✅ View logs
✅ Modify resources
✅ Delete resources

Cannot do:
❌ Delete the project itself
❌ Modify RBAC roles
❌ Create ServiceAccounts
❌ Modify ResourceQuotas
```

---

### **4.4 ResourceQuota (Prevents Resource Hogging)**

OpenShift creates a ResourceQuota to limit total resource consumption:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: my-app
spec:
  hard:
    # Compute resources
    requests.cpu: "10"           # Max 10 CPU cores requested
    requests.memory: "20Gi"      # Max 20 GB memory requested
    limits.cpu: "20"             # Max 20 CPU cores limited
    limits.memory: "40Gi"        # Max 40 GB memory limited
    
    # Pod count
    pods: "100"                  # Max 100 pods in project
    
    # Storage
    requests.storage: "100Gi"    # Max 100 GB storage requested
    
    # Other resources
    services: "50"               # Max 50 services
    configmaps: "100"            # Max 100 config maps
    secrets: "100"               # Max 100 secrets
```

**Example usage:**

```bash
# View quota usage
oc describe resourcequota compute-resources -n my-app

# Output:
# Name:                  compute-resources
# Namespace:             my-app
# Resource               Used    Hard
# --------               ----    ----
# limits.cpu             4       20
# limits.memory          8Gi     40Gi
# pods                   15      100
# requests.cpu           2       10
# requests.memory        3Gi     20Gi
# requests.storage       20Gi    100Gi
# services               3       50
```

**What happens when quota is exceeded:**

```bash
# Try to create too many pods
oc scale deployment myapp --replicas=100

# Error:
# Error from server (Forbidden): 
# Deployment "myapp" is invalid: 
# pods "myapp-xxxxx" is forbidden: 
# exceeded quota: compute-resources, 
# requested: cpu=500m, used: cpu=9800m, limited: cpu=10
```

**Project hit its CPU quota limit!**

---

### **4.5 LimitRange (Default Pod Limits)**

OpenShift creates a LimitRange for automatic resource defaults:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: core-resource-limits
  namespace: my-app
spec:
  limits:
  # Pod-level limits
  - type: Pod
    max:
      cpu: "2"                  # Max 2 CPU per pod
      memory: "1Gi"             # Max 1 GB per pod
    min:
      cpu: "100m"               # Min 100m CPU per pod
      memory: "128Mi"           # Min 128 MB per pod
  
  # Container-level limits
  - type: Container
    max:
      cpu: "2"                  # Max 2 CPU per container
      memory: "1Gi"             # Max 1 GB per container
    min:
      cpu: "100m"               # Min 100m CPU per container
      memory: "128Mi"           # Min 128 MB per container
    default:
      cpu: "500m"               # Default CPU if not specified
      memory: "512Mi"           # Default memory if not specified
    defaultRequest:
      cpu: "100m"               # Default CPU request
      memory: "128Mi"           # Default memory request
```

**What this means:**

When you create a pod without specifying resources:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:1.0
    # No resources specified!
```

OpenShift automatically applies:
```yaml
resources:
  requests:
    cpu: "100m"                 # Request (guaranteed)
    memory: "128Mi"
  limits:
    cpu: "500m"                 # Limit (max allowed)
    memory: "512Mi"
```

**Why this is important:**

```
Without LimitRange:
├─ Pod uses unlimited CPU
├─ Pod uses unlimited memory
├─ Can crash cluster
└─ No predictability

With LimitRange:
├─ Pod max: 500m CPU, 512 MB
├─ Pod min: 100m CPU, 128 MB
├─ Predictable performance
├─ Cluster stable
└─ Fair for all projects
```

---

### **4.6 Network Policies (Security/Isolation)**

OpenShift creates default network policies:

```yaml
# Policy 1: Deny all ingress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: my-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress

# Policy 2: Allow pods within same namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-same-namespace
  namespace: my-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
      namespaceSelector:
        matchLabels:
          name: my-app
```

**What this means:**

```
Traffic Flow:

Pod A (in my-app) → Pod B (in my-app)     ✅ ALLOWED
                                           (same namespace)

Pod A (in my-app) → Pod C (in other-app)  ❌ BLOCKED
                                           (different namespace)

External client → Pod A (in my-app)       ❌ BLOCKED
                                           (unless explicitly allowed)

Pod A (in my-app) → Kubernetes API        ❌ BLOCKED
                                           (unless explicitly allowed)
```

---

## **5. RBAC in Projects**

### **Default Roles**

OpenShift provides pre-configured cluster roles that can be used in projects:

**1. edit Role**
```
Can do:
✅ Create, read, update, delete pods
✅ Create, read, update, delete services
✅ Create, read, update, delete deployments
✅ Create, read, update, delete configmaps
✅ Create, read, update, delete secrets
✅ View logs
✅ Port forward

Cannot do:
❌ Delete project
❌ Modify RBAC
❌ Create ServiceAccounts
❌ Modify ResourceQuotas
```

**2. view Role**
```
Can do:
✅ Read pods
✅ Read services
✅ Read deployments
✅ Read logs
✅ Describe resources

Cannot do:
❌ Create anything
❌ Modify anything
❌ Delete anything
❌ Execute commands in pods
```

**3. admin Role**
```
Can do:
✅ Everything in the project
✅ Delete the project
✅ Modify RBAC
✅ Create ServiceAccounts
✅ Modify quotas

This is full project ownership
```

---

### **Adding Users to Projects**

```bash
# Add user with 'edit' role (can create/modify resources)
oc adm policy add-role-to-user edit john -n my-app

# Add user with 'view' role (read-only)
oc adm policy add-role-to-user view jane -n my-app

# Add user as project admin
oc adm policy add-role-to-user admin bob -n my-app

# Remove role from user
oc adm policy remove-role-from-user edit john -n my-app

# Check who has what role
oc get rolebinding -n my-app
oc describe rolebinding -n my-app

# View user permissions
oc adm policy who-can create deployments -n my-app
oc adm policy who-can delete pods -n my-app
```

---

### **Service Account Permissions**

Service accounts have specific roles:

**builder Service Account:**
```bash
# Used by build pods
# Has permissions to:
├─ Read source code repositories
├─ Build images
├─ Push images to registry
└─ Trigger deployments
```

**deployer Service Account:**
```bash
# Used during rollouts
# Has permissions to:
├─ Create pods
├─ Update deployments
├─ Manage rolling updates
└─ Update status
```

**default Service Account:**
```bash
# Used by general application pods
# Has permissions to:
├─ Read Kubernetes API
├─ Read secrets in same namespace
├─ Read configmaps in same namespace
└─ Limited general-purpose access
```

---

## **6. Resource Quotas**

### **What is a ResourceQuota?**

A ResourceQuota enforces limits on total resource consumption in a namespace/project.

**Problem it solves:**

```
Without quotas:
Project A: Uses 100% of cluster CPU
Project B: Gets 0% CPU → cannot run anything
Project C: Stuck waiting
Result: Unfair, cluster overwhelmed

With quotas:
Project A: Limited to 30% CPU
Project B: Limited to 30% CPU
Project C: Limited to 30% CPU
Result: Fair distribution, predictable
```

### **Quota Types**

```yaml
# Compute Resources (CPU/Memory)
requests.cpu: "10"              # Total CPU requested
requests.memory: "20Gi"         # Total memory requested
limits.cpu: "20"                # Total CPU limit
limits.memory: "40Gi"           # Total memory limit

# Pod Count
pods: "100"                     # Maximum pods

# Storage
requests.storage: "100Gi"       # Total storage requested
persistentvolumeclaims: "10"    # Max PVCs

# Object Count
services: "50"                  # Max services
configmaps: "100"               # Max config maps
secrets: "100"                  # Max secrets
replicationcontrollers: "50"    # Max RC
```

### **Viewing Quota Usage**

```bash
# See current quota and usage
oc describe resourcequota -n my-app

# Real example output:
# Name:                      compute-resources
# Namespace:                 my-app
# Resource                   Used    Hard
# --------                   ----    ----
# limits.cpu                 4       20        (20% used)
# limits.memory              8Gi     40Gi      (20% used)
# pods                       15      100       (15% used)
# requests.cpu               2       10        (20% used)
# requests.memory            3Gi     20Gi      (15% used)
# requests.storage           20Gi    100Gi     (20% used)
```

### **When Quota is Exceeded**

```bash
# Error when creating pod over quota
oc create deployment myapp --image=myapp:1.0 --replicas=50

# Error:
# Error from server (Forbidden): 
# Deployment "myapp" is invalid: 
# pods "myapp-xxxxx" is forbidden: 
# exceeded quota: compute-resources, 
# requested: cpu=500m, used: cpu=9800m, limited: cpu=10000m
```

---

## **7. LimitRange (Default Resource Limits)**

### **What is LimitRange?**

LimitRange automatically applies default resource limits to pods and containers.

**Problem it solves:**

```
Without LimitRange:
└─ Pod created without limits uses unlimited resources
   └─ Can crash cluster

With LimitRange:
└─ Pod automatically gets default limits applied
   └─ Cannot exceed per-pod/container limits
   └─ Cluster stays healthy
```

### **LimitRange Configuration**

```yaml
# Default values if not specified
defaultRequest:
  cpu: "100m"           # Will request 100m if not specified
  memory: "128Mi"       # Will request 128 MB if not specified

# Maximum allowed per container
max:
  cpu: "2"              # Cannot exceed 2 CPU
  memory: "1Gi"         # Cannot exceed 1 GB

# Minimum allowed per container
min:
  cpu: "50m"            # Cannot go below 50m
  memory: "64Mi"        # Cannot go below 64 MB
```

### **Example: Creating Pod Without Resources**

**Pod definition (no resources specified):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:1.0
    # No resources field!
```

**After LimitRange applied:**
```yaml
# OpenShift automatically adds:
spec:
  containers:
  - name: app
    image: myapp:1.0
    resources:
      requests:
        cpu: "100m"       # Default request
        memory: "128Mi"
      limits:
        cpu: "500m"       # Default limit
        memory: "512Mi"
```

### **What Happens When Limits Exceeded**

```bash
# Try to create pod with too much CPU
oc create pod myapp --image=myapp:1.0 --limits=cpu=3

# Error:
# Error from server (Forbidden): 
# Pod "myapp" is invalid: 
# spec.containers[0].resources.limits.cpu: 
# Invalid value: "3": 
# must be less than or equal to 2
```

---

## **8. Network Policies**

### **What Are Network Policies?**

Network Policies control traffic flow between pods and external access.

**Problem they solve:**

```
Without Network Policies:
├─ Any pod can talk to any pod
├─ External can reach any pod
├─ No security
└─ Compliance issues!

With Network Policies:
├─ Deny all by default (secure)
├─ Allow specific traffic (explicit)
├─ Project isolated
└─ Compliance ready!
```

### **Default Policies in Project**

OpenShift creates two default policies:

**Policy 1: Deny All Ingress**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: my-app
spec:
  podSelector: {}           # Applies to all pods
  policyTypes:
  - Ingress                 # Blocks incoming traffic
  # No 'ingress' rules means deny all
```

**Policy 2: Allow Same-Namespace Communication**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-same-namespace
  namespace: my-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: my-app      # Allow from same namespace
```

### **Traffic Scenarios**

```
Scenario 1: Pod-to-Pod (Same Project)
Pod A (my-app) → Pod B (my-app)          ✅ ALLOWED
Reason: allow-from-same-namespace policy

Scenario 2: Pod-to-Pod (Different Projects)
Pod A (my-app) → Pod C (other-app)       ❌ BLOCKED
Reason: deny-all-ingress policy

Scenario 3: External to Pod
External client → Pod A (my-app)         ❌ BLOCKED
Reason: deny-all-ingress policy

Scenario 4: Pod to External API
Pod A (my-app) → api.github.com          ✅ ALLOWED
Reason: Egress not restricted by default

Scenario 5: Kubernetes API Access
Pod A → Kubernetes API                   ✅ ALLOWED
Reason: Service account token authenticates
```

### **Custom Network Policies**

To allow external traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external
  namespace: my-app
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector: {}  # From any namespace
    ports:
    - protocol: TCP
      port: 8080
```

**This allows:**
```
Any pod → Pod with label app=myapp on port 8080     ✅ ALLOWED
```

---

## **9. Managing Projects**

### **Basic Project Operations**

```bash
# Create project
oc new-project my-app

# Create with description
oc new-project my-app \
  --display-name="My Application" \
  --description="Production application for team A"

# List all projects
oc projects

# Current project
oc project

# Switch to different project
oc project production

# Get project details
oc describe project my-app

# Label project
oc label project my-app environment=production team=backend

# View project with labels
oc get project --show-labels

# Delete project
oc delete project my-app
```

### **Project Configuration**

```bash
# View project configuration
oc get project my-app -o yaml

# Edit project
oc edit project my-app

# Add annotations
oc annotate project my-app \
  owner="alice@company.com" \
  department="engineering"

# View annotations
oc get project my-app -o yaml | grep annotations
```

---

### **User Management in Projects**

```bash
# Add user with edit role
oc adm policy add-role-to-user edit alice -n my-app

# Add user with view role
oc adm policy add-role-to-user view bob -n my-app

# Add user as admin
oc adm policy add-role-to-user admin charlie -n my-app

# Remove role
oc adm policy remove-role-from-user edit alice -n my-app

# View role bindings
oc get rolebinding -n my-app

# View who can do what
oc adm policy who-can create deployments -n my-app
oc adm policy who-can delete secrets -n my-app

# Get permissions for specific user
oc adm policy user-info alice -n my-app
```

---

### **Resource Quota Management**

```bash
# View resource quotas
oc get resourcequota -n my-app

# Describe quota
oc describe resourcequota -n my-app

# Edit quota
oc edit resourcequota compute-resources -n my-app

# Create custom quota
oc create quota my-quota \
  --hard=cpu=10,memory=20Gi,pods=50 \
  -n my-app
```

---

### **LimitRange Management**

```bash
# View limit ranges
oc get limitrange -n my-app

# Describe limit range
oc describe limitrange -n my-app

# Edit limit range
oc edit limitrange core-resource-limits -n my-app

# Create custom limit range
oc create -f limitrange.yaml -n my-app
```

---

### **Network Policy Management**

```bash
# View network policies
oc get networkpolicy -n my-app

# Describe policy
oc describe networkpolicy deny-all-ingress -n my-app

# Edit policy
oc edit networkpolicy deny-all-ingress -n my-app

# Create custom policy
oc apply -f my-networkpolicy.yaml -n my-app

# Delete policy
oc delete networkpolicy my-policy -n my-app
```

---

## **10. Real-World Scenarios**

### **Scenario 1: Multi-Team Environment**

**Setup:**
```bash
# Team A gets project with medium resources
oc new-project team-a-prod --display-name="Team A Production"

# Give team members access
oc adm policy add-role-to-user edit alice -n team-a-prod
oc adm policy add-role-to-user edit bob -n team-a-prod
oc adm policy add-role-to-user view contractor1 -n team-a-prod  # View only

# Set resource quota for Team A
oc create quota team-a-quota \
  --hard=cpu=8,memory=16Gi,pods=50 \
  -n team-a-prod

# Team B gets project with different resources
oc new-project team-b-prod --display-name="Team B Production"

oc adm policy add-role-to-user edit charlie -n team-b-prod
oc adm policy add-role-to-user edit diana -n team-b-prod

# Set resource quota for Team B
oc create quota team-b-quota \
  --hard=cpu=4,memory=8Gi,pods=25 \
  -n team-b-prod
```

**Result:**
```
cluster/
├─ team-a-prod (8 CPU, 16 GB RAM)
│  ├─ alice (edit)
│  ├─ bob (edit)
│  └─ contractor1 (view)
└─ team-b-prod (4 CPU, 8 GB RAM)
   ├─ charlie (edit)
   └─ diana (edit)

Teams isolated, resources fair, access controlled!
```

---

### **Scenario 2: Multiple Environments**

**Setup:**
```bash
# Development (small resources, open access)
oc new-project myapp-dev --display-name="MyApp Development"
oc create quota dev-quota --hard=cpu=2,memory=4Gi,pods=20 -n myapp-dev
oc adm policy add-role-to-user edit dev-team -n myapp-dev

# Staging (medium resources, controlled access)
oc new-project myapp-staging --display-name="MyApp Staging"
oc create quota staging-quota --hard=cpu=4,memory=8Gi,pods=30 -n myapp-staging
oc adm policy add-role-to-user edit qa-team -n myapp-staging

# Production (large resources, restricted access)
oc new-project myapp-prod --display-name="MyApp Production"
oc create quota prod-quota --hard=cpu=16,memory=32Gi,pods=100 -n myapp-prod
oc adm policy add-role-to-user view dev-team -n myapp-prod  # View only
oc adm policy add-role-to-user edit ops-team -n myapp-prod  # Edit only
```

**Promotion flow:**
```
dev → staging → production
(small)  (medium)  (large)
(open)   (controlled) (restricted)
```

---

### **Scenario 3: Resource Allocation Based on Need**

**Company Setup:**
```bash
# High-traffic frontend service
oc new-project frontend
oc create quota frontend-quota \
  --hard=cpu=32,memory=64Gi,pods=200 \
  -n frontend
# Reason: High traffic, needs lots of resources

# Backend API service
oc new-project backend
oc create quota backend-quota \
  --hard=cpu=16,memory=32Gi,pods=100 \
  -n backend
# Reason: Medium traffic, database connections

# Low-traffic admin service
oc new-project admin
oc create quota admin-quota \
  --hard=cpu=4,memory=8Gi,pods=20 \
  -n admin
# Reason: Low traffic, small team
```

**Result:**
```
Total cluster: 100 CPU, 200 GB RAM

Allocated:
├─ frontend: 32 CPU, 64 GB RAM   (32%)
├─ backend: 16 CPU, 32 GB RAM    (16%)
└─ admin: 4 CPU, 8 GB RAM        (4%)

Reserved: 48 CPU, 96 GB RAM      (48% for growth)
```

---

## **11. Project Best Practices**

### **Naming Conventions**

```bash
# Good names (clear purpose)
oc new-project myapp-prod        # Application name + environment
oc new-project team-a-dev        # Team + environment
oc new-project database-prod     # Service + environment

# Bad names (confusing)
oc new-project project1          # Too generic
oc new-project temp              # Unclear purpose
oc new-project test123           # Meaningless
```

### **Quota Planning**

```bash
# Analyze application needs
├─ Peak CPU usage → Set quota 20-30% higher
├─ Peak memory usage → Set quota 20-30% higher
├─ Number of replicas → Set pod limit 2x needed
└─ Storage usage → Set quota 2x current

# Example:
Production app:
├─ Current CPU: 2 cores
├─ Current memory: 4 GB
├─ Replicas: 3 pods
├─ Storage: 50 GB

Set quotas:
├─ CPU: 4 cores (2x current)
├─ Memory: 8 GB (2x current)
├─ Pods: 10 (3x needed)
└─ Storage: 100 GB (2x current)
```

### **RBAC Best Practices**

```bash
# Use least privilege principle
├─ Don't give 'edit' role unless needed
├─ Give 'view' role for read-only access
├─ Reserve 'admin' for project owners
└─ Audit role assignments regularly

# Example setup
Project lead:   admin role       (full control)
Developers:     edit role        (can create/modify)
QA team:        view role        (read-only)
Contractors:    view role        (read-only)
```

### **Network Policy Best Practices**

```bash
# Start with deny-all (secure default)
├─ This is done automatically
└─ Add allow rules as needed

# Be specific
├─ Allow specific pods, not all
├─ Allow specific ports, not all
└─ Document why each rule exists

# Example: Only allow from ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-router
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: openshift-ingress
    ports:
    - protocol: TCP
      port: 8080
```

### **Monitoring Project Health**

```bash
# Check quota usage regularly
oc describe resourcequota -n my-app | grep -A 10 "Resource"

# View recent events
oc get events -n my-app --sort-by='.lastTimestamp'

# Check pod status
oc get pods -n my-app

# Monitor resource usage
oc top nodes
oc top pods -n my-app

# Describe project
oc describe project my-app
```

---

## **12. Key Takeaways**

### **What You Need to Remember**

1. **Project = Namespace + Superpowers**
   - Isolation like namespace
   - PLUS security, quotas, policies pre-configured
   - Ready to use immediately

2. **Automatic Setup**
   - Service accounts created (3 defaults)
   - RBAC pre-configured (edit role for users)
   - ResourceQuota enforces fair sharing
   - LimitRange sets automatic defaults
   - Network policies provide security

3. **Multi-tenant Friendly**
   - Teams isolated
   - Resources limited per project
   - No cross-project access by default
   - Perfect for shared clusters

4. **One Command**
   - `oc new-project my-app`
   - Everything configured
   - No manual YAML needed
   - Production ready in 1 minute

5. **Key Components**
   - Service Accounts: default, builder, deployer
   - RBAC: edit, view, admin roles
   - ResourceQuota: Total resource limits
   - LimitRange: Per-pod default limits
   - NetworkPolicy: Default deny-all

---

### **Common Commands**

```bash
# Project lifecycle
oc new-project my-app
oc project my-app
oc projects
oc describe project my-app
oc delete project my-app

# User management
oc adm policy add-role-to-user edit alice -n my-app
oc adm policy remove-role-from-user edit alice -n my-app
oc get rolebinding -n my-app

# Resource viewing
oc get resourcequota -n my-app
oc get limitrange -n my-app
oc get networkpolicy -n my-app

# Monitoring
oc describe resourcequota -n my-app
oc get events -n my-app
oc top pods -n my-app
```

---

### **Decision Guide**

```
Need multiple teams?           → Use Projects
Need resource fairness?        → Use ResourceQuota
Need automatic pod limits?     → LimitRange applied
Need network security?         → NetworkPolicy applied
Need RBAC control?            → Roles/RoleBindings created
Need prod-ready namespace?    → Use oc new-project
```

---

### **Comparison Summary**

| Aspect | Kubernetes Namespace | OpenShift Project |
|--------|-----|-----|
| **Creation time** | 1 minute (manual) | 1 minute (auto) |
| **Setup complexity** | Complex (manual) | Simple (auto) |
| **Ready to use?** | ❌ Need more setup | ✅ Immediately |
| **Production ready?** | ❌ Need work | ✅ Yes |
| **Multi-tenant?** | ⚠️ Possible | ✅ Perfect |
| **Default security** | ❌ Minimal | ✅ Secure |
| **Resource control** | ❌ Manual | ✅ Built-in |
| **User access control** | ⚠️ Manual RBAC | ✅ Pre-configured |

---

**✅ Topic 4 Complete**

When ready, reply:
- ✅ **"Ready for Topic 5"** → Move to: Routes ⭐ — OpenShift's way of exposing applications
- ❓ **"Need clarification on [section]"** — Ask about specific parts
