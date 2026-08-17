# **Topic 3: oc CLI — Compared with kubectl — Complete Notes**

---

## **Table of Contents**
1. Introduction
2. What is oc CLI?
3. Relationship Between kubectl and oc
4. Installation
5. Login & Authentication
6. Side-by-Side Comparison
7. Kubernetes Commands (Both Can Do)
8. OpenShift-Specific Commands (oc ONLY)
9. Real-World Examples
10. Command Reference
11. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

**oc = OpenShift Command-Line Interface (CLI)**

oc is the command-line tool for interacting with OpenShift clusters.

**kubectl = Kubernetes Command-Line Interface (CLI)**

kubectl is the command-line tool for interacting with Kubernetes clusters.

### **Key Relationship**

```
                    oc CLI
                     ↑
        ┌────────────┴────────────┐
        │                         │
    Kubernetes Features      OpenShift Features
    (Same as kubectl)        (Additional)
        │                         │
        ├─ oc get pods           ├─ oc new-project
        ├─ oc apply              ├─ oc new-app
        ├─ oc create             ├─ oc expose svc
        ├─ oc delete             ├─ oc new-build
        ├─ oc logs               ├─ oc start-build
        └─ oc exec               └─ oc describe imagestream
```

**Simple Concept:**
- oc = kubectl + OpenShift extensions
- oc is a SUPERSET of kubectl
- oc can do everything kubectl can do, PLUS more

---

## **2. What is oc CLI?**

### **Purpose**

oc CLI is used to:
- Authenticate to OpenShift clusters
- View and manage Kubernetes resources (pods, services, deployments, etc.)
- View and manage OpenShift-specific resources (routes, imagestreams, buildconfigs, projects)
- Deploy applications
- Build applications from source code
- View logs and debug applications
- Manage cluster configuration

### **Where oc Comes From**

oc is developed and maintained by Red Hat as part of OpenShift.

It's built on top of kubectl, extending it with OpenShift-specific functionality.

```
oc = kubectl + OpenShift magic
```

---

## **3. Relationship Between kubectl and oc**

### **Can You Use kubectl in OpenShift?**

**YES! 100%**

kubectl works perfectly in OpenShift for all Kubernetes operations.

**Example:**

```bash
# These all work in OpenShift:
kubectl get pods
kubectl get services
kubectl get deployments
kubectl apply -f deployment.yaml
kubectl create deployment myapp --image=myapp:1.0
kubectl delete pod myapp
kubectl logs pod-name
kubectl exec -it pod-name bash
kubectl describe node node-name
```

**Same commands as Kubernetes clusters.**

### **But You're Missing OpenShift Features**

If you ONLY use kubectl in OpenShift, you lose:
- Simple app deployment (`oc new-app`)
- Build pipelines (`oc new-build`)
- Routes (`oc expose svc`)
- Projects (`oc new-project`)
- ImageStreams (`oc import-image`)
- And many more...

### **Why Use oc Over kubectl?**

```
kubectl: Bare bones, requires lots of YAML
oc:      Developer-friendly, quick commands

Example: Deploying an app

kubectl:
  1. Write deployment YAML
  2. Write service YAML
  3. Write ingress YAML
  4. kubectl apply everything
  5. Configure DNS
  6. 10 minutes

oc:
  1. oc new-app myapp
  2. oc expose svc/myapp
  3. Done!
  4. 1 minute
```

---

## **4. Installation**

### **macOS**

```bash
# Using Homebrew
brew install openshift-cli

# Verify installation
oc version
```

### **Linux**

```bash
# Download latest release
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz

# Extract
tar -xzf openshift-client-linux.tar.gz

# Move to PATH
sudo mv oc /usr/local/bin/
sudo mv kubectl /usr/local/bin/

# Verify
oc version
```

### **Windows**

```bash
# Using Chocolatey
choco install openshift-cli

# Or download from:
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
# Extract and add to PATH
```

### **From Red Hat Console**

```bash
# Download from:
# https://console.redhat.com/openshift/downloads

# Select your OS, download the CLI
# Extract and add to PATH
```

### **Verify Installation**

```bash
oc version
# Output:
# Client Version: 4.13.0
# Kustomize Version: v4.5.4

# kubectl is included!
kubectl version
# Output: Same as oc
```

---

## **5. Login & Authentication**

### **oc Login (Recommended)**

**Method 1: Interactive Login**

```bash
oc login https://api.my-cluster.example.com:6443

# Prompts for:
# Username:
# Password:
```

**Method 2: Username/Password on Command**

```bash
oc login https://api.my-cluster.example.com:6443 \
  --username=admin \
  --password=xxxxx
```

**Method 3: Token Login**

```bash
oc login --token=sha256~ABC123XYZ789 \
  https://api.my-cluster.example.com:6443
```

**Method 4: OAuth (Opens Browser)**

```bash
oc login https://api.my-cluster.example.com:6443
# Opens browser for OAuth/SAML login
```

### **After Login - Credentials Stored**

```bash
# Credentials saved to:
~/.kube/config

# This file contains:
# - Cluster API URL
# - Your credentials (token or certificate)
# - Context information
```

### **kubectl Login (Same Method)**

```bash
# kubectl uses same kubeconfig
kubectl config view

# Same login process works for kubectl
kubectl config get-contexts
kubectl config use-context my-context
```

---

## **6. Side-by-Side Comparison**

### **Kubernetes Resources (Both kubectl and oc)**

```bash
# Pods
kubectl get pods              ≈ oc get pods
kubectl describe pod myapp    ≈ oc describe pod myapp
kubectl logs pod-name         ≈ oc logs pod-name
kubectl exec -it pod bash     ≈ oc exec -it pod bash
kubectl create pod myapp      ≈ oc create pod myapp
kubectl delete pod myapp      ≈ oc delete pod myapp

# Services
kubectl get svc               ≈ oc get svc
kubectl expose pod myapp      ≈ oc expose pod myapp
kubectl describe svc myapp    ≈ oc describe svc myapp

# Deployments
kubectl get deployment        ≈ oc get deployment
kubectl create deployment     ≈ oc create deployment
kubectl scale deployment      ≈ oc scale deployment
kubectl rollout status        ≈ oc rollout status

# ConfigMaps & Secrets
kubectl get configmap         ≈ oc get configmap
kubectl get secret            ≈ oc get secret
kubectl create secret         ≈ oc create secret

# Nodes
kubectl get nodes             ≈ oc get nodes
kubectl describe node         ≈ oc describe node
kubectl cordon node           ≈ oc cordon node
kubectl drain node            ≈ oc drain node

# All produce identical output
```

---

### **OpenShift-Specific Resources (oc ONLY)**

These commands only work in oc, not kubectl:

```bash
# Projects (OpenShift namespace wrapper)
oc new-project my-app         # kubectl: create namespace
oc projects                   # kubectl: no equivalent
oc project my-app             # kubectl: no equivalent
oc describe project my-app    # kubectl: describe namespace

# Deployment Config (OpenShift-specific)
oc get dc                      # kubectl: no equivalent
oc describe dc myapp          # kubectl: no equivalent
oc rollout history dc/myapp   # kubectl: rollout history deployment (different)
oc rollout undo dc/myapp      # kubectl: rollout undo deployment

# Routes (OpenShift alternative to Ingress)
oc get route                   # kubectl: get ingress
oc create route               # kubectl: no equivalent
oc describe route myapp       # kubectl: describe ingress
oc expose svc/myapp           # kubectl: create ingress (manual)

# ImageStreams (OpenShift image management)
oc get imagestream            # kubectl: no equivalent
oc describe imagestream myapp # kubectl: no equivalent
oc import-image myapp         # kubectl: no equivalent
oc tag myapp:latest myapp:v1  # kubectl: no equivalent

# BuildConfigs (OpenShift build system)
oc get buildconfig            # kubectl: no equivalent
oc new-build                  # kubectl: no equivalent
oc start-build myapp-build    # kubectl: no equivalent
oc describe bc/myapp-build    # kubectl: no equivalent

# Quick app deployment
oc new-app nodejs:16          # kubectl: no equivalent (requires YAML)
oc new-app https://github.com/user/repo  # kubectl: no equivalent
```

---

## **7. Kubernetes Commands (Both Can Do)**

### **Pod Operations**

```bash
# View pods
oc get pods                          # List pods
oc get pods -o wide                  # Detailed list
oc get pods -n namespace             # In specific namespace
oc get pods -l app=myapp             # Filter by label
oc get pods -A                       # All namespaces

# Pod details
oc describe pod myapp                # Detailed info
oc logs pod-name                     # View logs
oc logs pod-name -f                  # Follow logs (like tail -f)
oc logs pod-name --previous          # Previous pod logs (if crashed)
oc logs pod-name -c container-name   # Specific container logs

# Execute commands in pod
oc exec -it pod-name bash            # Get shell in pod
oc exec -it pod-name -- ls /app      # Run command in pod
oc exec pod-name -- cat /app/file.txt

# Port forwarding
oc port-forward pod/myapp 8080:8080  # Forward local:8080 → pod:8080
oc port-forward pod/myapp 9090:8080  # Forward local:9090 → pod:8080

# Debugging pod
oc debug pod/myapp                   # Start debug container
oc describe pod myapp                # See pod details
oc get pod myapp -o yaml             # Full YAML definition
```

### **Service Operations**

```bash
# View services
oc get svc                           # List services
oc describe svc myapp                # Service details
oc get svc -n namespace              # In specific namespace

# Expose pod as service
oc expose pod myapp                  # Create service from pod
oc expose pod myapp --port=80        # With specific port
oc expose pod myapp --type=LoadBalancer

# Expose deployment as service
oc expose deployment myapp
```

### **Deployment Operations**

```bash
# View deployments
oc get deployment                    # List deployments
oc describe deployment myapp         # Deployment details
oc get deployment -o yaml            # Full YAML

# Create deployment
oc create deployment myapp --image=myapp:1.0

# Scale deployment
oc scale deployment myapp --replicas=5

# Update deployment
oc set image deployment/myapp app=myapp:2.0
oc set env deployment/myapp KEY=value
oc set resources deployment/myapp --limits=cpu=500m,memory=256Mi

# Rollout management
oc rollout status deployment/myapp   # Rollout status
oc rollout history deployment/myapp  # Rollout history
oc rollout undo deployment/myapp     # Rollback to previous
oc rollout undo deployment/myapp --to-revision=2
```

### **Creating Resources from YAML**

```bash
# Apply YAML (create or update)
oc apply -f deployment.yaml
oc apply -f .                        # All YAML files in directory
oc apply -f https://example.com/file.yaml

# Create YAML
oc create -f deployment.yaml

# Delete resources
oc delete pod myapp
oc delete deployment myapp
oc delete -f deployment.yaml
oc delete all -l app=myapp           # Delete by label
```

### **ConfigMaps & Secrets**

```bash
# ConfigMaps
oc create configmap my-config --from-file=config.yaml
oc create configmap my-config --from-literal=KEY=value
oc get configmap
oc describe configmap my-config
oc delete configmap my-config

# Secrets
oc create secret generic my-secret --from-literal=password=xxx
oc create secret docker-registry my-secret --docker-server=...
oc get secret
oc describe secret my-secret
```

---

## **8. OpenShift-Specific Commands (oc ONLY)**

### **Project Management**

```bash
# Create project
oc new-project my-app               # Creates namespace + RBAC + quotas
oc new-project my-app --description="My application"

# List projects
oc projects                         # Shows all accessible projects

# Switch to project
oc project my-app

# Current project
oc project

# Project details
oc describe project my-app

# Delete project
oc delete project my-app
```

**What's created when you do `oc new-project`:**

```
Creates:
├─ Namespace: my-app
├─ Service Accounts: default, builder, deployer
├─ Role Bindings: Users get edit role
├─ Network Policies: Isolate traffic
├─ ResourceQuota: Limit resources
└─ LimitRange: Default resource limits
```

---

### **Quick Application Deployment**

```bash
# Deploy from image
oc new-app nodejs:16                    # Uses image
oc new-app nodejs:16 --name=myapp       # With custom name
oc new-app nodejs:16 --env=KEY=value    # With environment

# Deploy from Git repository
oc new-app https://github.com/user/repo#main
oc new-app https://github.com/user/repo --name=myapp

# Deploy and expose immediately
oc new-app nodejs:16 --expose           # Creates service + route

# View what was created
oc status                               # Shows deployment status
oc get all                              # Shows all resources created
```

---

### **Routes (Exposing Applications)**

```bash
# Create route from service
oc expose svc/myapp                     # Creates route
oc expose svc/myapp --hostname=myapp.example.com

# List routes
oc get route

# Route details
oc describe route myapp

# Edit route
oc edit route myapp

# Create route manually
oc create route http myapp --service=myapp

# Delete route
oc delete route myapp
```

---

### **Build System**

```bash
# Create build config
oc new-build nodejs:16                  # From base image
oc new-build nodejs:16 --name=myapp-build
oc new-build nodejs:16 --binary=false --name=myapp-build

# Build from Git
oc new-build nodejs:16 \
  --source=https://github.com/user/repo#main \
  --name=myapp-build

# Start build manually
oc start-build myapp-build              # Trigger build
oc start-build myapp-build --follow     # Follow build progress

# Build status
oc get build                            # List all builds
oc describe build myapp-build-1         # Build details
oc logs build/myapp-build-1             # Build logs

# Build config
oc get buildconfig                      # List build configs
oc describe bc/myapp-build              # Build config details
oc edit buildconfig myapp-build         # Edit build config
```

---

### **ImageStreams (Image Management)**

```bash
# Import image from external registry
oc import-image myapp --from=quay.io/org/myapp:latest --confirm

# List image streams
oc get imagestream

# Image stream details
oc describe imagestream myapp           # Shows all tagged versions

# Tag image
oc tag myapp:latest myapp:stable        # Create alias
oc tag myapp:v1.0 myapp:production      # Tag old version

# Delete image stream
oc delete imagestream myapp
```

---

### **DeploymentConfig (OpenShift Alternative to Deployment)**

```bash
# Create deployment config
oc create deploymentconfig myapp --image=myapp:latest

# List deployment configs
oc get dc

# Deployment config details
oc describe dc myapp

# Rollout history
oc rollout history dc/myapp             # All revisions

# Rollback to previous version
oc rollout undo dc/myapp                # Undo last change
oc rollout undo dc/myapp --to-revision=2  # Specific revision

# Set environment variables
oc set env dc/myapp KEY=value

# Set resources
oc set resources dc/myapp --limits=cpu=500m

# Set triggers
oc set triggers dc/myapp
```

---

### **Admin Commands (Cluster Administration)**

```bash
# Add role to user
oc adm policy add-role-to-user admin user1 -n my-app

# Add cluster role to user
oc adm policy add-cluster-role-to-user cluster-admin user1

# Remove role from user
oc adm policy remove-role-from-user edit user1 -n my-app

# List user permissions
oc adm policy who-can create deployments

# View RBAC
oc get role
oc get rolebinding
oc get clusterrole
oc get clusterrolebinding

# Manage node cordons
oc cordon node-name                     # Prevent pods from scheduling
oc uncordon node-name                   # Allow pods again
oc drain node-name --ignore-daemonsets  # Drain for maintenance
```

---

### **Debugging Commands**

```bash
# Current status
oc status                               # Overall cluster status
oc status -v                            # Verbose status

# Debug pod
oc debug pod/myapp                      # Start debug container

# Describe everything
oc describe all                         # All resource details
oc describe all -n my-app               # In specific namespace

# Get YAML of resource
oc get pod myapp -o yaml                # Full resource definition
oc get svc myapp -o json                # JSON format

# View events
oc get events                           # Cluster events
oc get events -n my-app                 # Namespace events
oc describe node node-name               # Shows recent events
```

---

## **9. Real-World Examples**

### **Example 1: Deploy Node.js Application**

**Using oc (Simple):**

```bash
# 1. Create project
oc new-project myapp-prod

# 2. Deploy from image
oc new-app nodejs:16 --name=myapp --env=NODE_ENV=production

# 3. Scale up
oc scale deployment myapp --replicas=3

# 4. Expose to the world
oc expose svc/myapp --hostname=myapp.example.com

# 5. Check status
oc status

# Done! Application is running
oc get route        # Shows external URL
```

**Using kubectl (Complex):**

```bash
# 1. Create namespace
kubectl create namespace myapp-prod

# 2. Create deployment (manual YAML)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp-prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nodejs
        image: nodejs:16
        env:
        - name: NODE_ENV
          value: production
EOF

# 3. Create service (manual YAML)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp-prod
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF

# 4. Create ingress (manual YAML)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp-prod
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
EOF

# Much more complex!
```

**Comparison:**
- oc: 5 commands, ~1 minute
- kubectl: Manual YAML, 3 resources, ~10 minutes

---

### **Example 2: Build and Deploy from Source**

**Using oc (Automatic):**

```bash
# 1. Create build config
oc new-build nodejs:16 \
  --source=https://github.com/myorg/myapp#main \
  --name=myapp-build

# 2. Deploy from built image
oc new-app myapp-build --name=myapp

# 3. Expose
oc expose svc/myapp

# 4. Watch deployment
oc status

# Every time code is pushed to GitHub:
# 1. Webhook triggers build
# 2. Image is built
# 3. Deployment auto-updates
# All automatic!
```

**Using kubectl (Manual):**

```bash
# 1. Set up external CI/CD (Jenkins, GitHub Actions)
# 2. Configure webhook
# 3. Write build script
# 4. Configure deployment trigger
# 5. Manual YAML files
# ...lots of manual configuration
```

---

### **Example 3: Scaling and Updates**

**Using oc:**

```bash
# Scale deployment
oc scale deployment myapp --replicas=5

# Update image
oc set image deployment/myapp nodejs=nodejs:18

# Update environment
oc set env deployment/myapp NODE_ENV=staging

# Check status
oc rollout status deployment/myapp

# Rollback if needed
oc rollout undo deployment/myapp
```

**Using kubectl (Same):**

```bash
# kubectl can do all of these too
kubectl scale deployment myapp --replicas=5
kubectl set image deployment myapp nodejs=nodejs:18
kubectl set env deployment/myapp NODE_ENV=staging
kubectl rollout status deployment/myapp
kubectl rollout undo deployment/myapp
```

---

## **10. Command Reference**

### **Most Used oc Commands**

```bash
# Authentication
oc login https://api.cluster.com:6443
oc logout
oc whoami

# Project management
oc new-project my-app
oc project my-app
oc projects

# Simple deployment
oc new-app nodejs:16 --name=myapp
oc expose svc/myapp
oc status

# Pod operations
oc get pods
oc logs pod-name
oc exec -it pod-name bash
oc port-forward pod/myapp 8080:8080

# Deployment operations
oc get deployment
oc scale deployment myapp --replicas=5
oc set image deployment/myapp app=myapp:2.0
oc rollout undo deployment/myapp

# Build system
oc new-build nodejs:16 --name=myapp-build
oc start-build myapp-build
oc logs bc/myapp-build

# Routes
oc expose svc/myapp
oc get route
oc describe route myapp

# ImageStreams
oc import-image myapp --from=quay.io/org/myapp
oc describe imagestream myapp

# Admin
oc adm policy add-role-to-user edit user1 -n my-app
oc describe project my-app
```

---

### **kubectl Commands (Also Work in oc)**

```bash
# Resource viewing
kubectl get pods
kubectl describe pod
kubectl get svc
kubectl get deployment
kubectl get nodes

# Resource creation
kubectl create deployment myapp --image=myapp:1.0
kubectl expose deployment myapp --port=80

# Resource updates
kubectl apply -f file.yaml
kubectl set image deployment/myapp app=myapp:2.0

# Debugging
kubectl logs pod-name
kubectl exec -it pod-name bash
kubectl port-forward pod/myapp 8080:8080

# Configuration
kubectl config view
kubectl config use-context my-context
kubectl get context

# All produce same results in oc
```

---

## **11. Key Takeaways**

### **What You Need to Remember**

1. **oc = kubectl + OpenShift**
   - oc can do everything kubectl can do
   - PLUS oc has OpenShift-specific features

2. **kubectl Works in OpenShift**
   - All kubectl commands work fine
   - But you miss OpenShift advantages

3. **Use oc for OpenShift**
   - Simpler commands (oc new-app)
   - Automatic setup (oc expose)
   - OpenShift features (routes, builds, etc.)
   - Better developer experience

4. **Use kubectl When**
   - You want vendor-neutral commands
   - Working with pure Kubernetes
   - Team is already kubectl-proficient
   - But you lose OpenShift benefits

5. **Key Differences**

| Task | kubectl | oc |
|------|---------|-----|
| Deploy app | Manual YAML | `oc new-app` |
| Expose app | Create Ingress | `oc expose svc` |
| Build from source | External CI/CD | `oc new-build` |
| Project isolation | Namespace only | `oc new-project` (with RBAC) |
| Routes | Ingress | `oc get route` |
| Image management | External | ImageStreams built-in |

---

### **Command Cheat Sheet**

```bash
# Basics
oc login https://api.cluster.com:6443
oc whoami
oc projects
oc project my-app

# Deployment
oc new-app nodejs:16
oc status
oc get all

# Access
oc expose svc/myapp
oc get route

# Debugging
oc logs pod-name
oc exec -it pod-name bash
oc describe pod pod-name

# Scaling
oc scale deployment myapp --replicas=5

# Updates
oc set image deployment/myapp app=myapp:2.0
oc rollout undo deployment/myapp

# Admin
oc adm policy add-role-to-user edit user1 -n my-app
```

---

### **When to Choose**

```
Learning OpenShift?           → Use oc
Need simple deployment?       → Use oc
Multi-environment setup?      → Use oc
Team knows kubectl?           → Use kubectl (but learn oc later)
Building complex apps?        → Use oc
Want OpenShift features?      → Use oc

TLDR: For OpenShift, always use oc!
```

---

### **One More Thing**

**Both are installed with OpenShift:**

```bash
# When you install oc, you get kubectl too!
oc version
kubectl version

# They share the same kubeconfig
export KUBECONFIG=~/.kube/config

# Both work, but oc is better for OpenShift
```

---

## **Summary Table: oc vs kubectl**

| Aspect | kubectl | oc |
|--------|---------|-----|
| **CLI Purpose** | Kubernetes management | OpenShift management |
| **Works in Kubernetes?** | ✅ Yes | ❌ No |
| **Works in OpenShift?** | ✅ Yes | ✅ Yes |
| **Kubernetes commands** | ✅ All | ✅ All |
| **OpenShift commands** | ❌ None | ✅ All |
| **Learning curve** | Medium | Easy (if know kubectl) |
| **Deployment speed** | Slow (manual YAML) | Fast (automatic) |
| **Application deployment** | Manual YAML | `oc new-app` |
| **Exposing apps** | Create Ingress | `oc expose svc` |
| **Building from source** | ❌ Not included | ✅ BuildConfigs |
| **Routes** | ❌ Not available | ✅ Available |
| **ImageStreams** | ❌ Not available | ✅ Available |
| **Projects** | Basic namespace | Enhanced with RBAC |
| **Project creation** | `kubectl create ns` | `oc new-project` |
| **Recommended for OpenShift?** | ⚠️ Works but limited | ✅ Recommended |

---

## **Practice Scenarios**

### **Scenario 1: You Know kubectl, Using OpenShift**

```
What you can do:
✅ All your kubectl knowledge still works
✅ oc commands available for additional features

What to do:
1. Start using oc instead of kubectl
2. Learn oc new-app for deployments
3. Learn oc expose for routing
4. Learn oc new-build for builds
5. Enjoy OpenShift productivity!
```

### **Scenario 2: You Don't Know kubectl, Using OpenShift**

```
What to do:
1. Learn oc commands (they're simpler!)
2. You'll understand kubectl later
3. Start with oc new-app, oc expose, oc status
4. Gradually learn other commands
5. You're actually in a better position!
```

### **Scenario 3: Team Wants Kubernetes-Only Commands**

```
You can:
✅ Use only kubectl commands in OpenShift
✅ Everything works!

You lose:
❌ oc new-app (manual YAML required)
❌ oc expose (use kubectl ingress instead)
❌ oc new-build (use external CI/CD)
❌ ImageStreams (use external registry)
❌ Routes (use Ingress)

Recommendation:
→ Learn oc, you'll love it!
```

---

**✅ Topic 3 Complete**

When ready, reply:
- ✅ **"Ready for Topic 4"** → Move to: Projects — OpenShift's enhanced namespaces
- ❓ **"Need clarification on [section]"** — Ask about specific parts
