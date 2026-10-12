# **Topic 14: OpenShift Networking — Pods, Services, DNS, Ingress & NetworkPolicy ⭐ — Complete Notes**

> **Sandbox practicability:** ✅ Mostly.
> ✅ Services, endpoints, DNS lookups, pod-to-pod tests, **NetworkPolicy** in your own project.
> ⚠️ Reading cluster network config (`network.config`) may be forbidden.
> ❌ EgressFirewall/EgressIP, IngressController changes, CNI settings are admin-only.

---

## **Table of Contents**
1. Introduction
2. The Network Layers
3. Cluster Network: OVN-Kubernetes
4. Services
5. DNS
6. Ingress: Routers & Routes (Recap)
7. NetworkPolicy
8. OpenShift Policy Labels (Ingress & Monitoring)
9. Egress Control
10. Multiple Networks (Multus)
11. Service Mesh (Overview)
12. ROSA / AWS Networking
13. Troubleshooting
14. Real-World Examples
15. Best Practices
16. Hands-on Lab (Sandbox)
17. Key Takeaways

---

## **1. Introduction**

You know Kubernetes networking: every pod gets an IP, pods reach each other without NAT, Services give stable names. **OpenShift keeps all of that** and adds:

- A **default CNI** (OVN-Kubernetes) installed and managed for you
- **Routes** and a built-in **HAProxy router** (Topic 5)
- **Egress controls** (firewall, fixed egress IPs)
- **Policy labels** for ingress and monitoring traffic
- **Multus** for multiple network interfaces
- **Service Mesh** via an Operator

```
Internet
   │
   ▼
Load balancer (AWS NLB/ELB)
   │
   ▼
Router pods (HAProxy)  ── Route ──▶  Service ──▶  Pods  (cluster network)
```

---

## **2. The Network Layers**

| Layer | What | Who manages it |
|---|---|---|
| **Pod network** | IP per pod (default `10.128.0.0/14`) | CNI (OVN-Kubernetes) |
| **Service network** | Virtual IPs for Services (default `172.30.0.0/16`) | kube-proxy replacement in OVN-K |
| **Node network** | VM/host IPs | Cloud VPC |
| **Ingress** | External → apps via Routes | Ingress Operator + router |
| **Egress** | Pods → outside | Node NAT, or EgressIP/Firewall |
| **DNS** | Names for Services and Pods | DNS Operator (CoreDNS) |

> The pod and service CIDRs are chosen **at install time** and are hard to change later, so plan them to avoid overlap with your VPC and on-prem ranges.

---

## **3. Cluster Network: OVN-Kubernetes**

| CNI | Status |
|---|---|
| **OVN-Kubernetes** | ✅ **Default** (from 4.12) and the only choice for new clusters |
| OpenShift SDN | ❌ Legacy; removed in newer versions. Migrate to OVN-K |
| Others (Calico, Cilium) | Possible on self-managed (partner CNIs) |

### **What OVN-Kubernetes gives you**
- Pod-to-pod and Service networking (Open vSwitch + OVN, **Geneve** overlay)
- **NetworkPolicy** enforcement
- **EgressIP**, **EgressFirewall**, **EgressQoS**
- Hybrid networking for Windows nodes
- IPv4 / IPv6 / dual-stack

```bash
oc get network.config cluster -o yaml        # may be forbidden
oc get pods -n openshift-ovn-kubernetes      # may be forbidden
```

```
Node A                         Node B
┌───────────────┐              ┌───────────────┐
│ pod 10.128.2.5│              │ pod 10.129.0.7│
│    OVS bridge │◀── Geneve ──▶│   OVS bridge  │
└───────────────┘   tunnel     └───────────────┘
```

---

## **4. Services**

| Type | Reachable from | Use |
|---|---|---|
| **ClusterIP** | Inside the cluster | Default. Backend for Routes |
| **NodePort** | Node IP:30000–32767 | Rare on cloud clusters |
| **LoadBalancer** | Outside, via a cloud LB | Non-HTTP traffic (TCP) |
| **ExternalName** | DNS CNAME to an external host | Alias to external service |
| **Headless** (`clusterIP: None`) | Direct pod IPs | StatefulSets, databases |

### **ClusterIP (your app)**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: landing-app
spec:
  type: ClusterIP
  selector:
    app: landing-app
  ports:
    - name: 8080-tcp
      port: 8080
      targetPort: 8080
```

### **LoadBalancer on ROSA**

```yaml
spec:
  type: LoadBalancer         # AWS creates an NLB/CLB (billable)
```

For **HTTP/HTTPS use a Route**, not a LoadBalancer Service. Reserve LoadBalancer for non-HTTP TCP. Each one costs money.

### **Endpoints**

A Service sends traffic only to **Ready pods** whose labels match `selector`.

```bash
oc get svc
oc get endpoints landing-app         # empty → selector mismatch or pods not Ready
oc get endpointslices
```

---

## **5. DNS**

CoreDNS runs under the **DNS Operator** in `openshift-dns`.

### **Names**

```
<service>.<project>.svc.cluster.local
landing-app.santha-dev.svc.cluster.local
```

| From | Short name that works |
|---|---|
| Same project | `landing-app` |
| Other project | `landing-app.santha-dev` or the full name |

### **Pod DNS config**
Pods get `search santha-dev.svc.cluster.local svc.cluster.local cluster.local` in `/etc/resolv.conf`, which is why short names work.

### **Test**

```bash
oc rsh deploy/landing-app
cat /etc/resolv.conf
getent hosts landing-app            # nslookup may not exist in the image
curl -s http://landing-app:8080/healthz
```

### **Headless Service DNS**
A headless Service returns **A records for every pod IP** (and `pod-0.svc` names for StatefulSets).

```bash
oc get dns.operator cluster -o yaml        # admin (DNS operator settings)
```

---

## **6. Ingress: Routers & Routes (Recap)**

(See **Topic 5** for details.)

```
Client ─▶ *.apps.<cluster> (DNS) ─▶ cloud LB ─▶ router pods (HAProxy) ─▶ Service ─▶ Pods
```

| Piece | Details |
|---|---|
| **Ingress Operator** | Runs the default **IngressController** in `openshift-ingress-operator` |
| **Router pods** | HAProxy in `openshift-ingress` |
| **Wildcard DNS** | `*.apps.<cluster-domain>` → the router's load balancer |
| **Sharding** | Several IngressControllers selecting Routes by label (public and internal) |
| **Kubernetes `Ingress` objects** | Supported. OpenShift turns them into Routes automatically |

```bash
oc get ingresscontroller -n openshift-ingress-operator      # may be forbidden
oc get route
```

> ❌ Changing an IngressController (replicas, certificates, sharding) is admin work. On ROSA, use the `rosa` CLI or the console for managed settings.

---

## **7. NetworkPolicy**

### **Default behaviour**
**All pods can talk to all pods**, even across projects, unless a NetworkPolicy says otherwise. A pod is isolated only once a policy **selects** it.

### **Four patterns to know**

**1. Deny all ingress (start closed)**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}          # all pods in the project
  policyTypes: [Ingress]
```

**2. Allow traffic within the same project**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
```

**3. Allow the router (so Routes keep working!)**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              policy-group.network.openshift.io/ingress: ""
```

**4. Allow only the app tier to reach the database**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-from-app-only
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: landing-app
      ports:
        - protocol: TCP
          port: 5432
```

### **Rules**
- Policies are **additive** (union of all that select a pod). There are no "deny" rules, because absence of an allow is the deny.
- You must apply `deny-all` **and** the allow rules. Applying only `deny-all` blocks the **router** too, so your Route returns "Application is not available".
- Policies are namespaced. Cross-project access uses `namespaceSelector`.

### **Egress policy**

```yaml
policyTypes: [Egress]
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: santha-dev
  - ports:                          # allow DNS
      - { protocol: UDP, port: 53 }
      - { protocol: TCP, port: 53 }
      - { protocol: UDP, port: 5353 }
      - { protocol: TCP, port: 5353 }
```

(OpenShift's DNS pods listen on 5353 internally, so allow it when you restrict egress.)

---

## **8. OpenShift Policy Labels (Ingress & Monitoring)**

OpenShift labels its system namespaces so you can reference them in policies:

| Need | Selector |
|---|---|
| Allow the **router** | `namespaceSelector: matchLabels: policy-group.network.openshift.io/ingress: ""` |
| Allow **monitoring** (Prometheus scraping) | `namespaceSelector: matchLabels: network.openshift.io/policy-group: monitoring` |
| Allow another project | `namespaceSelector: matchLabels: kubernetes.io/metadata.name: <project>` |

```yaml
# allow Prometheus to scrape metrics
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            network.openshift.io/policy-group: monitoring
```

Newer versions also add **AdminNetworkPolicy** and **BaselineAdminNetworkPolicy**: cluster-scoped policies written by admins that sit **above** or **below** user policies.

---

## **9. Egress Control**

Controlling traffic **leaving** the cluster. ❌ These are admin objects.

| Feature | Purpose |
|---|---|
| **EgressFirewall** | Allow/deny destinations by CIDR or DNS name per project |
| **EgressIP** | Give a project's outbound traffic a **fixed source IP** (partners whitelist it) |
| **EgressRouter** | Redirect egress via a router pod |
| **NetworkPolicy egress** | Pod-level egress rules (user-writable) |

```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressFirewall
metadata:
  name: default
  namespace: santha-dev
spec:
  egress:
    - type: Allow
      to: { dnsName: api.github.com }
    - type: Deny
      to: { cidrSelector: 0.0.0.0/0 }
```

```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: egressip-prod
spec:
  egressIPs: ["10.0.1.100"]
  namespaceSelector:
    matchLabels:
      env: prod
```

---

## **10. Multiple Networks (Multus)**

Pods have **one** interface by default. **Multus** adds secondary interfaces, used for telco, SR-IOV and storage networks.

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: storage-net
spec:
  config: '{ "cniVersion":"0.3.1", "type":"macvlan", "master":"eth1", "ipam":{"type":"dhcp"} }'
```

```yaml
# pod annotation
metadata:
  annotations:
    k8s.v1.cni.cncf.io/networks: storage-net
```

Know it exists. You'll meet it in telco and bare-metal work, not in a typical ROSA web app.

---

## **11. Service Mesh (Overview)**

**OpenShift Service Mesh** (Istio, installed via an **Operator**, Topic 7 and 8) adds:

| Feature | Benefit |
|---|---|
| **mTLS** between services | Encrypted and authenticated pod-to-pod traffic |
| **Traffic management** | Canary, retries, timeouts, circuit breakers |
| **Observability** | Traces, metrics and a service graph (Kiali) |
| **Policy** | Per-service authorization |

Use it when you have **many microservices** that need uniform security and telemetry. For a few apps, Routes plus NetworkPolicy are enough.

---

## **12. ROSA / AWS Networking**

| Topic | Detail |
|---|---|
| **VPC** | Cluster nodes live in your VPC subnets (private + public) |
| **Subnets** | Multi-AZ: pick subnets in 3 AZs for high availability |
| **Load balancers** | Router uses an **AWS NLB/CLB**; each `type: LoadBalancer` Service adds another |
| **Private cluster / PrivateLink** | API and apps are reachable only inside the VPC (or via VPN/Direct Connect). Red Hat SRE uses PrivateLink |
| **Egress** | NAT gateways for private subnets (a major cost) |
| **Security groups** | Created and managed by ROSA |
| **Connecting to other systems** | VPC peering, Transit Gateway, VPN (see your migration/VPN notes) |

> Your sandbox is a pre-built cluster, so you consume this layer without configuring it.

---

## **13. Troubleshooting**

| Symptom | Check | Cause / fix |
|---|---|---|
| Route: "Application is not available" | `oc get endpoints <svc>` | Empty endpoints → selector mismatch or pods not Ready |
| Route fails **after** adding a NetworkPolicy | `oc get networkpolicy` | Router blocked. Add `allow-from-openshift-ingress` |
| Pod can't reach another pod | `oc rsh <pod>` + `curl <svc>:<port>` | NetworkPolicy, wrong port, or pod not Ready |
| DNS name doesn't resolve | `cat /etc/resolv.conf`, `getent hosts <name>` | Wrong project/name, or egress policy blocks DNS (53/5353) |
| `connection refused` | `oc logs`, port check | App not listening on that port or on `0.0.0.0` |
| Works inside cluster, not outside | Route/TLS | Route host, TLS and router DNS |
| Pod can't reach the internet | Egress firewall or NAT | EgressFirewall rule, or private subnet without NAT |
| LoadBalancer stuck `<pending>` | `oc describe svc` | Cloud quota or IAM/subnet tag problem |
| Intermittent failures to a pod | `oc get endpoints` | Readiness probe flapping |

### **Debug order**

```bash
oc get route,svc,endpoints,pods -l app=<app>
oc describe svc <svc>
oc get networkpolicy
oc rsh <pod> curl -sv http://<svc>:<port>/
oc debug node/<node>     # admin ❌ (host networking tools)
```

---

## **14. Real-World Examples**

### **Example 1: Lock down `santha-dev` properly**

```yaml
# 1. deny everything inbound
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: deny-all }
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# 2. pods in the project can talk to each other
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-same-namespace }
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
---
# 3. router (Routes) can reach the app
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-from-openshift-ingress }
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              policy-group.network.openshift.io/ingress: ""
---
# 4. Prometheus can scrape
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-from-openshift-monitoring }
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              network.openshift.io/policy-group: monitoring
```

### **Example 2: Prove isolation works**

```bash
oc new-project other-proj                                  # if allowed
oc new-app --image=quay.io/openshifttest/hello-openshift   # any test pod
# from other-proj:
oc rsh deploy/hello-openshift curl -m 3 http://landing-app.santha-dev.svc:8080/healthz
#   before the policy: 200 OK     after deny-all: timeout
```

### **Example 3: Debug an empty endpoint list**

```bash
oc get svc landing-app -o jsonpath='{.spec.selector}'        # {"app":"landing-app"}
oc get pods --show-labels                                    # do labels match?
oc get pods                                                  # READY 1/1 ?
```

### **Example 4: Call another project's Service**

```bash
curl http://landing-app.santha-dev.svc.cluster.local:8080/api/info
```

---

## **15. Best Practices**

- ✅ Use **Routes** for HTTP/HTTPS and **LoadBalancer** only for non-HTTP TCP
- ✅ Start with **deny-all**, then allow the router, same-namespace and monitoring
- ✅ Always keep a policy allowing **`policy-group.network.openshift.io/ingress`**
- ✅ Label pods clearly (`app`, `tier`) so policies stay readable
- ✅ Choose **non-overlapping CIDRs** at install time (pod, service, VPC, on-prem)
- ✅ Use **EgressIP** when partners need to allow-list your outbound address
- ✅ Keep NetworkPolicies in **Git**
- ❌ Don't expose databases through Routes or LoadBalancers
- ❌ Don't rely on "obscurity". Without a NetworkPolicy, any pod can reach any pod

---

## **16. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted · ❌ admin only

| # | Task | Status |
|---|---|---|
| 1 | `oc get svc,endpoints,pods -o wide` and match Service → endpoints → pod IPs | ✅ |
| 2 | `oc rsh deploy/landing-app` then `cat /etc/resolv.conf` and `curl localhost:8080/healthz` | ✅ |
| 3 | From a second pod, `curl http://landing-app:8080/api/info` (short name) | ✅ |
| 4 | Use the full name `landing-app.santha-dev.svc.cluster.local` | ✅ |
| 5 | Break the Service selector and watch endpoints go empty (the Route fails), then fix it | ✅ |
| 6 | Apply `deny-all` **alone**, confirm the Route breaks, then add `allow-from-openshift-ingress` and see it recover | ✅ |
| 7 | Add `allow-same-namespace` and confirm pod-to-pod works again | ✅ |
| 8 | `oc get network.config cluster -o yaml` (see the pod/service CIDRs) | ⚠️ |
| 9 | Test isolation from a second project | ⚠️ (needs another project) |
| 10 | Create an EgressFirewall or EgressIP | ❌ |
| 11 | Change the IngressController | ❌ |

### **Expected learning outcomes**
- You can trace Route → Service → Endpoints → Pod.
- You can write NetworkPolicies that don't break your Route.
- You know which networking features are admin-only and why.

---

## **17. Key Takeaways**

1. **OVN-Kubernetes** is the default CNI. OpenShift SDN is legacy.
2. Defaults: pod CIDR `10.128.0.0/14`, service CIDR `172.30.0.0/16`, **set at install time**.
3. **Routes + router** handle HTTP(S) ingress, and LoadBalancer Services handle non-HTTP TCP.
4. **No NetworkPolicy = everything is open.** After `deny-all`, you must allow the **router**.
5. OpenShift labels (`policy-group.network.openshift.io/ingress`, `network.openshift.io/policy-group: monitoring`) make system-traffic rules easy.
6. **Egress** (EgressIP, EgressFirewall) is admin-controlled.
7. **Empty endpoints** is the first thing to check when a Route says "not available".
8. **Service Mesh** and **Multus** are optional add-ons for advanced needs.

### **Common Commands**

```bash
oc get svc,endpoints,route,networkpolicy
oc describe svc <name>
oc rsh <pod> curl -sv http://<svc>:<port>/
oc get pods --show-labels
oc get network.config cluster -o yaml
oc apply -f networkpolicy.yaml
```

---

**✅ Topic 14 Complete**

When ready, reply:
- ✅ **"Ready for Topic 15"** → Move to: Storage (PV, PVC, StorageClass, CSI)
- ❓ **"Need clarification on [section]"**
