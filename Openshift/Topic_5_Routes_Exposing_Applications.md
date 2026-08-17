# **Topic 5: Routes ⭐ — OpenShift's Way of Exposing Applications — Complete Notes**

---

## **Table of Contents**
1. Introduction
2. What is a Route?
3. Why Routes Exist (vs Kubernetes Ingress)
4. How Routes Work (Architecture)
5. Route vs Ingress - Complete Comparison
6. Creating Routes
7. Route Components & Features
8. TLS/SSL Options
9. Advanced Routing (Canary, Traffic Splitting)
10. Route Operations (View, Edit, Delete)
11. Real-World Examples
12. Best Practices
13. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

**Route** = OpenShift's way to expose applications to the outside world

**Think of it like:**
```
Kubernetes Ingress:     You build the bridge (install controller, manage SSL, etc.)
OpenShift Route:        Pre-built bridge, just use it (one command)
```

**Route = Ingress but better**

---

## **2. What is a Route?**

### **Simple Explanation**

A Route is an API object that exposes HTTP/HTTPS applications to external users by:
- Mapping a hostname to a service
- Routing traffic to pods
- Managing SSL/TLS
- Providing external access

### **Purpose**

Routes solve the problem: "How do I let external users access my application in the cluster?"

**Answer:** Create a Route!

```
User → Route → Service → Pod
       (hostname mapping)
```

---

## **3. Why Routes Exist (vs Kubernetes Ingress)**

### **Kubernetes Ingress Problem**

Kubernetes provides Ingress API but not implementation:

```bash
# Kubernetes Ingress workflow:
1. Install Ingress Controller         ← Manual, 30+ min
   (nginx, traefik, or other)
   
2. Manage SSL certificates           ← Manual, complex
   (cert-manager, manual renewal)
   
3. Configure DNS                      ← Manual
   (Create DNS record)
   
4. Write Ingress YAML                ← Complex syntax
   (Multiple fields, multiple resources)
   
5. Debug issues                       ← Multiple layers
   (Controller, ingress, service, pod, DNS)
```

**Complex, manual, error-prone!**

---

### **OpenShift Route Solution**

OpenShift provides complete implementation:

```bash
# OpenShift Route workflow:
1. Router pre-deployed              ✅ Already running
   
2. SSL automatic                    ✅ Managed by OpenShift
   (Let's Encrypt or configured CA)
   
3. DNS managed                      ✅ Cluster domain
   (*.apps.cluster.example.com)
   
4. Simple command                   ✅ One-liner
   oc expose svc/myapp
   
5. Debug easily                     ✅ Single layer
   oc describe route myapp
```

**Simple, automatic, integrated!**

---

### **Comparison: Setup Time**

```
Kubernetes Ingress Setup:
├─ Install controller: 30 min
├─ Configure DNS: 15 min
├─ Manage SSL certs: 30 min
├─ Write Ingress YAML: 20 min
└─ Total: ~2 hours

OpenShift Route Setup:
├─ Run: oc expose svc/myapp
└─ Total: 30 seconds

OpenShift is 240x faster!
```

---

## **4. How Routes Work (Architecture)**

### **Route Components**

```
External Traffic
    ↓ (HTTPS)
┌──────────────────────────────────┐
│  OpenShift Router                │
│  (HAProxy-based)                 │
│  - Listens on port 80, 443       │
│  - Routes by hostname            │
│  - Terminates SSL                │
│  - Distributed across nodes      │
└──────────────┬───────────────────┘
               ↓ (HTTP to pod port)
        ┌──────────────────┐
        │ Kubernetes       │
        │ Service          │
        │ (Load balancer)  │
        └────────┬─────────┘
                 ↓ (Select pods)
        ┌────────────────┐
        │ Pod 1 (myapp)  │
        ├────────────────┤
        │ Pod 2 (myapp)  │
        ├────────────────┤
        │ Pod 3 (myapp)  │
        └────────────────┘
```

---

### **Traffic Flow**

**Step 1: User makes request**
```
User: curl https://myapp.example.com/api/users
```

**Step 2: DNS Resolution**
```
myapp.example.com → Resolves to Router IP
                   (e.g., 192.168.1.100)
```

**Step 3: Router receives traffic**
```
Router listens on 192.168.1.100:443
Receives request with Host: myapp.example.com
```

**Step 4: Route lookup**
```
Router looks for Route with host: myapp.example.com
Finds Route pointing to Service: myapp
```

**Step 5: Service load balances**
```
Service: myapp receives request
Selects pod with label app=myapp
(Could be pod1, pod2, or pod3)
```

**Step 6: Pod processes**
```
Pod receives request on port 8080
Container handles request
Sends response back
```

**Step 7: Response sent to user**
```
Response flows back through:
Pod → Service → Router → User
```

---

### **Key Difference from Ingress**

```
Kubernetes Ingress:
├─ You install controller
├─ Multiple moving parts
├─ Manual SSL management
└─ Complex debugging

OpenShift Router:
├─ Pre-deployed by OpenShift
├─ Integrated system
├─ Automatic SSL
└─ Easy debugging
```

---

## **5. Route vs Ingress - Complete Comparison**

### **Installation & Deployment**

| Aspect | Ingress | Route |
|--------|---------|-------|
| **Controller** | Must install (nginx, traefik, etc.) | Built-in, pre-deployed |
| **Multiple controllers?** | Yes, each adds complexity | Single Router per cluster |
| **Installation time** | 30-60 minutes | Already running |
| **Configuration** | Multiple resources needed | Single Route resource |
| **Setup complexity** | High (multiple moving parts) | Low (one simple resource) |

---

### **SSL/TLS Management**

| Aspect | Ingress | Route |
|--------|---------|-------|
| **SSL setup** | Manual (cert-manager or manual) | Automatic |
| **Certificate issuer** | External (Let's Encrypt, etc.) | Integrated (Let's Encrypt or CA) |
| **Renewal** | Manual or via cert-manager | Automatic |
| **Multiple certs** | Manual for each domain | Automatic per route |
| **Certificate errors** | Hard to debug | Easy to debug |

---

### **DNS Management**

| Aspect | Ingress | Route |
|--------|---------|-------|
| **DNS creation** | Manual (create DNS entry) | Automatic (cluster domain) |
| **DNS updates** | Manual when IP changes | Automatic |
| **Wildcard DNS** | Manual setup | Built-in *.apps.cluster.com |
| **External DNS** | Additional tool needed | Not needed |

---

### **Features & Capabilities**

| Feature | Ingress | Route |
|---------|---------|-------|
| **Host-based routing** | ✅ Yes | ✅ Yes |
| **Path-based routing** | ✅ Yes | ✅ Yes |
| **Traffic splitting** | ❌ Needs service mesh | ✅ Built-in (weight) |
| **Canary deployments** | ⚠️ Complex (Istio/Linkerd) | ✅ Native support |
| **Blue-green deployments** | ⚠️ Complex | ✅ Native support |
| **A/B testing** | ⚠️ Complex | ✅ Native support |
| **TLS termination** | Manual | Automatic |
| **Re-encryption** | Manual | Automatic |
| **Passthrough SSL** | Possible but complex | Simple |

---

### **Configuration Complexity**

**Kubernetes Ingress YAML:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
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
```

**OpenShift Route YAML:**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
spec:
  host: myapp.example.com
  to:
    kind: Service
    name: myapp
  port:
    targetPort: 8080
  tls:
    termination: edge
```

**OpenShift is much simpler!**

---

### **Operations & Debugging**

| Aspect | Ingress | Route |
|--------|---------|-------|
| **View resources** | `kubectl get ingress` | `oc get route` |
| **Describe resource** | `kubectl describe ingress` | `oc describe route` |
| **Debug SSL issues** | Complex (cert-manager logs, etc.) | Simple (route status) |
| **Debug routing** | Complex (controller logs) | Simple (route shows service) |
| **View external URL** | Ingress IP + manual DNS | Automatic hostname |
| **Health checks** | Limited | Built-in |

---

### **Complete Comparison Table**

| Criterion | Ingress | Route | Winner |
|-----------|---------|-------|--------|
| **Setup time** | ~2 hours | ~1 minute | 🏆 Route |
| **Ongoing maintenance** | High | Low | 🏆 Route |
| **SSL management** | Manual | Automatic | 🏆 Route |
| **DNS management** | Manual | Automatic | 🏆 Route |
| **Canary support** | ❌ No | ✅ Yes | 🏆 Route |
| **Developer experience** | ⚠️ Complex | ✅ Simple | 🏆 Route |
| **Production ready** | ⚠️ Possible | ✅ Yes | 🏆 Route |
| **Standardization** | ✅ Kubernetes standard | ❌ OpenShift only | 🏆 Ingress |
| **Multi-cluster** | ✅ Portable | ⚠️ OpenShift only | 🏆 Ingress |

---

## **6. Creating Routes**

### **Method 1: Expose Service (Simplest)**

**Command:**
```bash
oc expose svc/myapp
```

**What it does:**
```
Creates a Route automatically:
├─ Hostname: myapp-project.apps.cluster.example.com
├─ Service: myapp
├─ Port: Inferred from service
├─ TLS: edge termination
└─ Ready to use!
```

**Test it:**
```bash
# Get the route
oc get route

# Output:
# NAME    HOST/PORT                                       PATH   SERVICES   PORT    TERMINATION
# myapp   myapp-myproject.apps.cluster.example.com              myapp      8080    edge

# Access your app
curl https://myapp-myproject.apps.cluster.example.com
```

---

### **Method 1.5: Expose with Custom Hostname**

```bash
oc expose svc/myapp --hostname=myapp.example.com
```

**Result:**
```
Route created:
├─ Hostname: myapp.example.com
├─ Service: myapp
└─ SSL automatically managed
```

---

### **Method 2: Create Route YAML**

**Create file: route.yaml**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
  namespace: default
spec:
  # Hostname for accessing app
  host: myapp.example.com
  
  # Where traffic goes
  to:
    kind: Service
    name: myapp
    weight: 100
  
  # Pod port to connect to
  port:
    targetPort: 8080
  
  # SSL configuration
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

**Apply it:**
```bash
oc apply -f route.yaml
```

---

### **Method 3: Create with CLI Options**

```bash
# Basic route
oc create route http myapp-route \
  --service=myapp

# With hostname
oc create route https myapp-route \
  --service=myapp \
  --hostname=myapp.example.com

# With custom port
oc create route edge myapp-route \
  --service=myapp \
  --port=8080

# With traffic splitting
oc create route edge myapp-route \
  --service=myapp-v1 \
  --service-weight=myapp-v1=70 \
  --service=myapp-v2 \
  --service-weight=myapp-v2=30
```

---

## **7. Route Components & Features**

### **Basic Route Fields**

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp              # Route name (unique in project)
  namespace: default       # Project/namespace
  labels:                  # For categorization
    app: myapp
    version: v1
  annotations:             # Additional metadata
    description: "Production route"
spec:
  host: myapp.example.com  # External hostname
  
  to:                      # Primary service target
    kind: Service
    name: myapp
    weight: 100            # Traffic weight (%)
  
  alternateBackends:       # Alternate service targets
  - kind: Service
    name: myapp-canary
    weight: 10
  
  port:
    targetPort: 8080       # Pod port
  
  tls:                     # SSL/TLS configuration
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
    certificate: |         # Custom cert (optional)
      -----BEGIN CERTIFICATE-----
      ...
    key: |                 # Private key
      -----BEGIN PRIVATE KEY-----
      ...
    caCertificate: |       # CA cert
      -----BEGIN CERTIFICATE-----
      ...
    destinationCACertificate: |  # For re-encrypt
      -----BEGIN CERTIFICATE-----
      ...
```

---

### **Host Field**

```yaml
# Specific hostname
host: myapp.example.com

# Wildcard hostname
host: "*.example.com"     # Matches any.example.com

# Empty (uses generated hostname)
# host: ""
# Results in: myapp-project.apps.cluster.example.com
```

---

### **Weight Field (Traffic Splitting)**

```yaml
# 100% to primary service
to:
  kind: Service
  name: myapp
  weight: 100

# Split traffic
to:
  kind: Service
  name: myapp-v1
  weight: 90      # 90%

alternateBackends:
- kind: Service
  name: myapp-v2
  weight: 10      # 10%

# Result: 90% traffic to v1, 10% to v2
```

---

## **8. TLS/SSL Options**

### **Edge Termination (HTTPS at Router)**

**Scenario:** Router handles SSL, pod receives HTTP

```yaml
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

**Flow:**
```
Client HTTPS → Router HTTPS → Service HTTP → Pod HTTP
               (SSL ends here)
```

**Use when:**
- ✅ Pod doesn't support HTTPS
- ✅ Don't want SSL overhead on pods
- ✅ Want centralized SSL management

---

### **Re-encrypt Termination (HTTPS both sides)**

**Scenario:** Router handles client SSL, pod handles its own SSL

```yaml
spec:
  tls:
    termination: reencrypt
    destinationCACertificate: |
      -----BEGIN CERTIFICATE-----
      MIICljCCAX4CCQCKz0Td7bZqEjANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV
      ...
      -----END CERTIFICATE-----
```

**Flow:**
```
Client HTTPS → Router HTTPS → Pod HTTPS
               (SSL here)    (and here)
```

**Use when:**
- ✅ Pod has its own SSL certificate
- ✅ Need end-to-end encryption
- ✅ Pod security requires SSL

---

### **Passthrough Termination (HTTPS at Pod only)**

**Scenario:** Router forwards encrypted traffic, pod handles SSL

```yaml
spec:
  tls:
    termination: passthrough
```

**Flow:**
```
Client HTTPS → Router HTTPS → Pod HTTPS
               (encrypted)    (pod decrypts)
```

**Use when:**
- ✅ Pod handles all SSL/TLS
- ✅ Need specific SSL certificate on pod
- ✅ Pod needs full control

---

### **HTTP Only (No SSL)**

**Scenario:** No encryption

```yaml
spec:
  port:
    targetPort: 8080
  # No tls field = HTTP only
```

**Flow:**
```
Client HTTP → Router HTTP → Pod HTTP
```

**Use when:**
- ✅ Internal only (not public)
- ✅ Development environment
- ⚠️ Never for production!

---

### **Automatic SSL Redirect**

**Redirect HTTP to HTTPS:**

```yaml
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

**Result:**
```
User hits:  http://myapp.example.com
Redirected to: https://myapp.example.com
```

---

## **9. Advanced Routing (Canary, Traffic Splitting)**

### **Canary Deployment Pattern**

**Scenario:** Test new version with small % of traffic

**Setup:**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
spec:
  host: myapp.example.com
  
  # Production version (majority of traffic)
  to:
    kind: Service
    name: myapp-v1
    weight: 95      # 95% traffic
  
  # New version (testing)
  alternateBackends:
  - kind: Service
    name: myapp-v2
    weight: 5       # 5% traffic
  
  port:
    targetPort: 8080
  tls:
    termination: edge
```

**Traffic split:**
```
95% of users → v1 (stable)
5% of users → v2 (new, testing)
```

**Progression:**
```
Initial:    95/5
Step 1:     90/10
Step 2:     75/25
Step 3:     50/50
Step 4:     25/75
Final:      0/100 (v2 becomes primary)
```

---

### **Blue-Green Deployment**

**Scenario:** Two complete deployments, switch instantly

**Setup - Blue (Current):**
```bash
oc create deployment myapp-blue --image=myapp:1.0
oc expose deployment myapp-blue --port=8080 --name=myapp-blue
```

**Setup - Green (New):**
```bash
oc create deployment myapp-green --image=myapp:2.0
oc expose deployment myapp-green --port=8080 --name=myapp-green
```

**Route pointing to Blue:**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
spec:
  host: myapp.example.com
  to:
    kind: Service
    name: myapp-blue
  port:
    targetPort: 8080
```

**Switch to Green (when ready):**
```bash
oc patch route myapp -p '{"spec":{"to":{"name":"myapp-green"}}}'

# All traffic instantly switches to green!
```

---

### **A/B Testing (50/50 Split)**

**Scenario:** Test two versions equally

```yaml
spec:
  host: myapp.example.com
  to:
    kind: Service
    name: myapp-variant-a
    weight: 50
  alternateBackends:
  - kind: Service
    name: myapp-variant-b
    weight: 50
```

**Result:**
```
50% of requests → Variant A
50% of requests → Variant B
```

---

## **10. Route Operations**

### **View Routes**

```bash
# List routes in current project
oc get route

# Output:
# NAME    HOST/PORT                              SERVICES   PORT       TERMINATION
# myapp   myapp.example.com                      myapp      8080       edge
# api     api.example.com                        api-svc    3000       re-encrypt

# List routes in all projects
oc get route -A

# List with more details
oc get route -o wide

# Get route as YAML
oc get route myapp -o yaml

# Get route as JSON
oc get route myapp -o json
```

---

### **Describe Route**

```bash
# Full route details
oc describe route myapp

# Output:
# Name:           myapp
# Namespace:      default
# Created:        5 minutes ago
# Labels:         app=myapp
# Annotations:    <none>
# Requested Host: myapp.example.com
# Exposed on:     *.apps.cluster.example.com
# Path:           <none>
# TLS Termination: edge
# Insecure Policy: redirect
# Endpoints:      10.129.0.1:8080, 10.129.0.2:8080, 10.129.0.3:8080
```

---

### **Edit Route**

```bash
# Edit in default editor
oc edit route myapp

# Patch route (change hostname)
oc patch route myapp -p '{"spec":{"host":"newhostname.example.com"}}'

# Patch route (change service)
oc patch route myapp -p '{"spec":{"to":{"name":"new-service"}}}'

# Patch route (change weights)
oc patch route myapp -p '{"spec":{"to":{"weight":100}}}'

# Patch route (disable HTTPS redirect)
oc patch route myapp -p '{"spec":{"tls":{"insecureEdgeTerminationPolicy":"Allow"}}}'
```

---

### **Delete Route**

```bash
# Delete single route
oc delete route myapp

# Delete multiple routes
oc delete route myapp api admin

# Delete all routes in project
oc delete route --all

# Delete with confirmation
oc delete route myapp -i    # Interactive
```

---

### **Get External URL**

```bash
# Simple way
oc get route

# Get just hostname
oc get route myapp -o jsonpath='{.spec.host}'

# Get full URL
oc get route myapp -o jsonpath='{.spec.host}' | xargs -I {} echo "https://{}"

# In script
URL=$(oc get route myapp -o jsonpath='{.spec.host}')
curl https://$URL
```

---

## **11. Real-World Examples**

### **Example 1: Simple HTTP Route**

**Step 1: Create application**
```bash
oc new-project myapp
oc create deployment myapp --image=nginx:latest
```

**Step 2: Create service**
```bash
oc expose deployment myapp --port=80
```

**Step 3: Expose service (create route)**
```bash
oc expose svc/myapp
```

**Step 4: Get external URL**
```bash
oc get route myapp
# Shows: myapp-myapp.apps.cluster.example.com

# Test
curl http://myapp-myapp.apps.cluster.example.com
# Success!
```

---

### **Example 2: HTTPS with Custom Hostname**

**Step 1: Create application**
```bash
oc create deployment myapp --image=myapp:1.0 --port=8080
oc expose deployment myapp --port=8080
```

**Step 2: Create HTTPS route**
```bash
oc create route edge myapp \
  --service=myapp \
  --hostname=myapp.company.com \
  --port=8080 \
  --insecure-policy=Redirect
```

**Step 3: Test**
```bash
# HTTPS works
curl https://myapp.company.com
# Success!

# HTTP redirects to HTTPS
curl http://myapp.company.com
# Redirected to https://...
```

---

### **Example 3: Canary Deployment**

**Step 1: Current production (v1)**
```bash
oc create deployment myapp-v1 --image=myapp:1.0 --replicas=3
oc expose deployment myapp-v1 --port=8080 --name=myapp-v1
```

**Step 2: New version (v2) being tested**
```bash
oc create deployment myapp-v2 --image=myapp:2.0 --replicas=1
oc expose deployment myapp-v2 --port=8080 --name=myapp-v2
```

**Step 3: Create route with canary**
```bash
cat > route.yaml <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
spec:
  host: myapp.company.com
  to:
    kind: Service
    name: myapp-v1
    weight: 95
  alternateBackends:
  - kind: Service
    name: myapp-v2
    weight: 5
  port:
    targetPort: 8080
  tls:
    termination: edge
EOF

oc apply -f route.yaml
```

**Step 4: Monitor v2**
```bash
# Watch v2 logs
oc logs -f deployment/myapp-v2

# When stable, shift traffic
oc patch route myapp -p '{"spec":{"to":{"weight":75},"alternateBackends":[{"kind":"Service","name":"myapp-v2","weight":25}]}}'

# When fully tested, make v2 primary
oc patch route myapp -p '{"spec":{"to":{"name":"myapp-v2","weight":100}}}'
```

---

### **Example 4: Blue-Green Deployment**

**Step 1: Deploy Blue (production)**
```bash
oc create deployment myapp-blue --image=myapp:1.0 --replicas=3
oc expose deployment myapp-blue --port=8080 --name=myapp-blue
oc expose svc/myapp-blue --hostname=myapp.company.com
```

**Step 2: Deploy Green (new version)**
```bash
oc create deployment myapp-green --image=myapp:2.0 --replicas=3
oc expose deployment myapp-green --port=8080 --name=myapp-green
```

**Step 3: Test Green**
```bash
# Test green with port-forward
oc port-forward svc/myapp-green 8080:8080 &
curl localhost:8080/health
```

**Step 4: Switch to Green (one command)**
```bash
oc patch route myapp-blue -p '{"spec":{"to":{"name":"myapp-green"}}}'

# All traffic instantly switches!
```

**Step 5: Keep or rollback**
```bash
# Keep Green (delete Blue)
oc delete deployment myapp-blue

# Rollback (switch back to Blue)
oc patch route myapp-blue -p '{"spec":{"to":{"name":"myapp-blue"}}}'
```

---

## **12. Best Practices**

### **Route Naming**

```bash
# Good names (clear purpose)
oc expose svc/myapp --name=myapp-prod
oc expose svc/api --name=api-v1

# Bad names
oc expose svc/myapp --name=route1      # Too generic
oc expose svc/api --name=temp          # Unclear
```

---

### **TLS Termination Choice**

```yaml
# For most cases: Edge (simpler, faster)
tls:
  termination: edge

# For specific SSL needs: Re-encrypt or Passthrough
# Only use if absolutely necessary (adds complexity)
```

---

### **Hostname Management**

```bash
# Use cluster domain (simple)
oc expose svc/myapp
# Results in: myapp-project.apps.cluster.example.com

# Use custom domain (production)
oc expose svc/myapp --hostname=myapp.company.com
# Requires: Custom domain configured in cluster
```

---

### **Traffic Weight Management**

```yaml
# For gradual rollout
95/5 → 90/10 → 75/25 → 50/50 → 25/75 → 0/100

# For instant switch
Blue-green deployment is safer
```

---

### **Monitoring Routes**

```bash
# Check route status
oc describe route myapp

# Check if external access works
curl https://myapp.example.com

# View pod metrics for route
oc top pods -l app=myapp

# View route events
oc get events -n default | grep route
```

---

## **13. Key Takeaways**

### **What You Need to Remember**

1. **Route = Simple Way to Expose Apps**
   - One command: `oc expose svc/myapp`
   - Automatic SSL
   - Built-in Router
   - Much simpler than Ingress

2. **Key Difference from Ingress**
   - Router: Pre-deployed, integrated
   - Ingress: You install controller
   - Route: Simple commands
   - Ingress: Complex YAML

3. **TLS Handling**
   - Automatic SSL certificates
   - No manual cert management
   - Automatic renewal
   - HTTP→HTTPS redirect available

4. **Advanced Features**
   - Canary deployments (traffic split)
   - Blue-green deployments (instant switch)
   - A/B testing (50/50 split)
   - All built-in!

5. **Operations**
   - View: `oc get route`
   - Edit: `oc edit route` or `oc patch route`
   - Delete: `oc delete route`
   - Describe: `oc describe route`

---

### **Common Commands Reference**

```bash
# Create routes
oc expose svc/myapp                    # Auto-generated hostname
oc expose svc/myapp --hostname=app.com # Custom hostname
oc create route edge route-name --service=svc-name

# View routes
oc get route                           # List all
oc describe route myapp                # Detailed view
oc get route myapp -o yaml             # YAML format

# Edit routes
oc edit route myapp                    # Edit in editor
oc patch route myapp -p '{...}'        # Update specific field

# Delete routes
oc delete route myapp                  # Delete single
oc delete route --all                  # Delete all

# Test access
curl https://myapp.example.com         # Test external
oc port-forward svc/myapp 8080:8080    # Test internal
```

---

### **When to Use Routes vs Ingress**

```
Use Routes if:
✅ You're on OpenShift
✅ You want simple setup
✅ You need automatic SSL
✅ You need traffic splitting
✅ You want developer-friendly

Use Ingress if:
✅ You're on vanilla Kubernetes
✅ You need vendor-neutral standard
✅ You're multi-cloud
✅ You already have controller
```

---

### **Route Termination Decision Tree**

```
Do pods need SSL?
├─ No → Edge (simplest)
│   └─ Router handles SSL, pods get HTTP
│
└─ Yes → Re-encrypt or Passthrough
    ├─ Need control over pod SSL? → Passthrough
    │  └─ Router forwards encrypted traffic
    │
    └─ Using CA cert? → Re-encrypt
       └─ Router SSL + Pod SSL
```

---

### **Deployment Pattern Choice**

```
Need gradual rollout?
├─ Yes → Canary (weight splitting)
│   └─ 95/5 → 90/10 → ... → 0/100
│
Need instant switch?
├─ Yes → Blue-Green
│   └─ Switch service instantly
│
Need to test equally?
└─ Yes → A/B Testing
    └─ 50/50 split
```

---

**✅ Topic 5 Complete**

When ready, reply:
- ✅ **"Ready for Topic 6"** → Move to: Security Context Constraints (SCC) ⭐
- ❓ **"Need clarification on [section]"** — Ask about specific parts
