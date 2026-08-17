# **Topic 1: OpenShift Architecture — What OpenShift Adds to Kubernetes**

---

## **1. Foundation: OpenShift = Kubernetes + Abstraction Layer**

**Basic Understanding:**
- OpenShift runs ON TOP of Kubernetes
- It adds abstractions, tooling, and operational features
- Your Kubernetes knowledge applies 100% — OpenShift doesn't replace it, it enhances it

**Key Difference:**
- **Kubernetes:** You get the core container orchestration
- **OpenShift:** You get Kubernetes + Developer Platform + Enterprise Features + integrated DevOps tools

---

## **2. Core Architectural Components**

### **Control Plane (Master Nodes)**
Same as Kubernetes, but OpenShift extends it:
- **API Server** — extended with OpenShift-specific APIs (Routes, Projects, Templates, ImageStreams, etc.)
- **Controller Manager** — additional controllers for OpenShift resources
- **Scheduler** — same Kubernetes scheduler
- **etcd** — distributed data store

**New for OpenShift:** OpenShift extends the API server with custom resources like:
- `Route` (replaces/abstracts Ingress)
- `Project` (wrapper around Namespaces with RBAC pre-configured)
- `DeploymentConfig` (alternative to Deployment, more integrated with build/deploy pipelines)
- `ImageStream` (manages container images internally)

### **Worker Nodes (Compute Nodes)**
- Same as Kubernetes nodes
- Run pods, containers
- Have kubelet, container runtime

### **Infrastructure Components (New/Different)**

| Component | Purpose | Kubernetes Equivalent |
|-----------|---------|-----|
| **Registry** | Internal container image registry | None (external registry needed) |
| **Router** | Ingress controller (built-in) | Ingress Controller (you install separately) |
| **Build Controller** | Builds container images from source code | None (use Jenkins, Tekton externally) |
| **Operators** | Manage complex stateful apps | Custom operators (you define) |
| **Web Console** | UI for management | Optional third-party |

---

## **3. Key Architectural Concepts (Basic → Intermediate)**

### **A. Projects (Not just Namespaces)**

**What is a Project?**
A Project is OpenShift's way of wrapping a Kubernetes namespace with pre-configured security and access controls.

**When you create a project:**

```bash
oc new-project my-app
```

**This single command creates:**
1. **Namespace** — my-app (same as Kubernetes namespace)
2. **Service Accounts** — default, builder, deployer (with appropriate roles pre-bound)
3. **RBAC (Role Bindings)** — Users automatically get edit permissions on their project
4. **Network Isolation Policies** — Traffic allowed within project, denied from external by default
5. **Resource Quotas** — Prevents one project from consuming all cluster resources
6. **Default LimitRange** — Default CPU/memory limits for pods

**Kubernetes way (manual setup):**
```bash
# Create namespace
kubectl create namespace my-app

# Manually create service accounts
kubectl create serviceaccount builder -n my-app
kubectl create serviceaccount deployer -n my-app

# Manually bind roles
kubectl create rolebinding edit --clusterrole=edit --serviceaccount=my-app:default -n my-app

# Manually create quotas
kubectl apply -f resourcequota.yaml

# Manually create network policies
kubectl apply -f networkpolicy.yaml
```

**OpenShift way (one command):**
```bash
oc new-project my-app
# Everything auto-configured!
```

---

### **B. Routes vs Ingress**

**Kubernetes Ingress Flow (What YOU manage):**

```
┌─────────────────┐
│  External User  │
│  my-app.example │
└────────┬────────┘
         │ (DNS points to Ingress IP)
         ▼
┌─────────────────────────────────────────┐
│  INGRESS CONTROLLER                     │
│  (You must deploy: nginx, traefik, etc) │
│  Watches: Ingress resources             │
│  Creates: Load balancer rules           │
└────────┬────────────────────────────────┘
         │ (Routes HTTP/HTTPS traffic)
         ▼
┌─────────────────────────────────────────┐
│  Service: my-app (Port 80)              │
│  Selector: app=my-app                   │
└────────┬────────────────────────────────┘
         │ (Load balances to pods)
         ▼
┌─────────────────────────────────────────┐
│  Pods running my-app:8080               │
│  ├─ Pod 1                               │
│  ├─ Pod 2                               │
│  └─ Pod 3                               │
└─────────────────────────────────────────┘
```

**Ingress YAML (Complex):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  rules:
  - host: my-app.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: my-app
            port:
              number: 80
```

**What you need to do in Kubernetes:**
1. Deploy an Ingress Controller (separate deployment)
2. Create Ingress resource
3. Configure DNS to point to Ingress IP
4. Manage SSL certificates manually

---

**OpenShift Route Flow (Built-in):**

```
┌─────────────────┐
│  External User  │
│  my-app.example │
└────────┬────────┘
         │ (DNS points to Router IP)
         ▼
┌──────────────────────────────────────────┐
│  OPENSHIFT ROUTER (Built-in)             │
│  - Pre-deployed on cluster               │
│  - Watches: Route resources              │
│  - Already configured & running          │
└────────┬─────────────────────────────────┘
         │ (Routes traffic via Route spec)
         ▼
┌──────────────────────────────────────────┐
│  Service: my-app (Port 8080)             │
│  Selector: app=my-app                    │
└────────┬─────────────────────────────────┘
         │ (Load balances to pods)
         ▼
┌──────────────────────────────────────────┐
│  Pods running my-app:8080                │
│  ├─ Pod 1                                │
│  ├─ Pod 2                                │
│  └─ Pod 3                                │
└──────────────────────────────────────────┘
```

**Route YAML (Simple):**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app
spec:
  host: my-app.example.com
  to:
    kind: Service
    name: my-app
    weight: 100
  port:
    targetPort: 8080
  tls:
    termination: edge
```

**Key difference:** 
- OpenShift Router is built-in, you don't need to deploy an Ingress controller

---

### **C. Container Image Management**

**Kubernetes way (You manage external registry):**
```bash
# Build image locally
docker build -t myregistry/myimage:1.0 .

# Push to external registry (Docker Hub, ECR, etc.)
docker push myregistry/myimage:1.0

# Create credentials secret (if needed)
kubectl create secret docker-registry my-secret ...

# Deploy using external registry image
kubectl apply -f deployment.yaml  # with image: myregistry/myimage:1.0
```

**OpenShift way (Built-in internal registry + ImageStreams):**
```bash
# Import image from external registry
oc import-image myimage --from=quay.io/org/image --confirm
# Creates ImageStream that tracks all versions

# Deploy using ImageStream
oc new-app myimage
# OpenShift knows where to get it
```

**What this means:**
- OpenShift has an internal registry built-in
- ImageStreams track all image versions (like Git for images)
- No need for external credential management

---

### **D. Build Pipeline (Intermediate)**

**OpenShift has built-in build capabilities:**

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: my-app-build
spec:
  source:
    git:
      uri: https://github.com/org/repo
      ref: main
  strategy:
    sourceStrategy:
      from:
        kind: ImageStreamTag
        name: nodejs:16
  output:
    to:
      kind: ImageStreamTag
      name: my-app:latest
```

**What this does automatically:**
1. Watches Git repository for changes
2. Pulls source code when Git push happens
3. Builds container image using S2I (Source-to-Image)
4. Pushes image to internal registry
5. Updates ImageStream
6. Triggers deployment update
7. Deploys new version

**Kubernetes way:**
- You need external CI/CD (Jenkins, GitHub Actions, GitLab CI)
- Manual workflow: code → build → push → deploy
- Complex setup and maintenance

---

## **4. Architecture Diagram: High-Level**

```
┌──────────────────────────────────────────────────────┐
│              OpenShift Cluster                        │
├──────────────────────────────────────────────────────┤
│  Master Nodes (Control Plane)                         │
│  ├─ API Server (+ OpenShift Extensions)              │
│  ├─ Controller Manager (+ OpenShift Controllers)     │
│  ├─ Scheduler                                        │
│  └─ etcd                                             │
├──────────────────────────────────────────────────────┤
│  Built-in Services                                    │
│  ├─ Internal Registry (manage images)                │
│  ├─ Router (replace Ingress controller)              │
│  ├─ Build Controllers (S2I, Docker builds)           │
│  └─ Operators (manage apps)                          │
├──────────────────────────────────────────────────────┤
│  Worker Nodes                                         │
│  ├─ kubelet + CRI-O                                  │
│  ├─ SDN/OVN (network)                                │
│  └─ Pods with containers                             │
└──────────────────────────────────────────────────────┘
```

---

## **5. Comparison: What Changes from Kubernetes?**

| Aspect | Kubernetes | OpenShift |
|--------|-----------|-----------|
| **Ingress** | Manual setup | Built-in Router |
| **Container Registry** | External | Internal registry included |
| **Building Images** | External CI/CD (Jenkins) | Built-in BuildConfigs |
| **Namespaces** | Basic isolation | Projects (richer RBAC) |
| **Deployment** | Deployment resource | Deployment + DeploymentConfig |
| **CLI** | `kubectl` | `oc` (superset of kubectl) |
| **Security** | Basic RBAC | Enhanced RBAC + Pod Security Policies |
| **Networking** | CNI plugins | OVN/SDN built-in |

---

## **6. Key Takeaways**

### **Basic Understanding**
1. OpenShift = Kubernetes core + enterprise layer
2. Projects replace namespaces (with better defaults)
3. Routes replace Ingress (built-in router)
4. BuildConfigs replace external CI/CD
5. Internal registry manages images automatically

### **Intermediate Concepts**
- ImageStreams track image versions across internal registry
- S2I (Source-to-Image) automates build pipelines
- Operators manage complex application lifecycles
- Pod Security Policies enforce security at admission level
- OVN/SDN provides advanced networking

---

## **7. What's the Same? (Everything Kubernetes Still Works)**

**All kubectl commands work in OpenShift:**
```bash
kubectl get pods                    # oc get pods (same)
kubectl create deployment           # oc create deployment (same)
kubectl apply -f deployment.yaml    # oc apply -f deployment.yaml (same)
kubectl logs pod-name               # oc logs pod-name (same)
kubectl exec -it pod-name bash      # oc exec -it pod-name bash (same)
```

**OpenShift is 100% Kubernetes-compatible!**

---

## **8. What's Different? (OpenShift-Only Features)**

```bash
# These are OpenShift-specific (don't exist in Kubernetes):
oc new-project my-app               # Create project (not just namespace)
oc new-app myimage                  # Deploy with templates
oc expose svc/myapp                 # Create Route (not Ingress)
oc new-build nodejs:16 --binary     # Create BuildConfig
oc start-build myapp-build          # Trigger build manually
oc describe imagestream myapp       # View ImageStream versions
```

---

**✅ Topic 1 Complete**

When ready, reply:
- ✅ **"Ready for Topic 2"** — Move to: OpenShift Installation & Cluster Access
- ❓ **"Need clarification on [section]"** — Ask about specific parts
