# **Topic 9: Deployments & Rollouts — Running Your App on OpenShift — Complete Notes**

> **Sandbox practicability:** ✅ Fully. Everything runs in your own project.
> This topic is built on the real manifests in `Openshift/sample-app/Deployment/` (the `landing-app`).

---

## **Table of Contents**
1. Introduction
2. Deployment vs DeploymentConfig
3. Anatomy of a Deployment (the `landing-app` Example)
4. Image Triggers (OpenShift's Special Feature)
5. Rollout Strategies
6. Configuration: ConfigMaps & Secrets
7. Health Probes
8. Resources (Requests & Limits)
9. Scaling & Autoscaling (HPA)
10. Rollouts, History & Rollback
11. Services & Routes Recap (the Whole Stack)
12. Kustomize: Deploy Everything in One Command
13. `oc new-app` and Import from Git
14. Troubleshooting
15. Real-World Examples
16. Best Practices
17. Hands-on Lab (Sandbox)
18. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

A **Deployment** declares how many copies of your app should run and which image they use. Kubernetes keeps reality matching that declaration.

```
You declare:   "3 replicas of landing-app, image X"
Controller:    Creates a ReplicaSet → creates 3 Pods → replaces any that die
```

On OpenShift you use the **same Kubernetes Deployment**, plus OpenShift extras (image triggers, Routes, restricted security).

### **The Full Stack for One App**

```
                Route  (hostname + TLS)
                  │
               Service (stable name + load balancing)
                  │
              Deployment ──▶ ReplicaSet ──▶ Pods
                  ▲
            ImageStream ◀── Build ◀── BuildConfig ◀── Git
```

Every box is a manifest in your `sample-app/Deployment/` folder: `route.yaml`, `service.yaml`, `deployment.yaml`, `imagestream.yaml`, `buildconfig.yaml`, `configmap.yaml`.

---

## **2. Deployment vs DeploymentConfig**

OpenShift 3 had its own **DeploymentConfig (dc)**. It's **deprecated**, so don't use it for new apps.

| | Deployment | DeploymentConfig |
|---|---|---|
| API | `apps/v1` (Kubernetes) | `apps.openshift.io/v1` |
| Controller | Kubernetes controller manager | OpenShift controller (a dedicated pod) |
| Underlying object | ReplicaSet | ReplicationController |
| Image triggers | Annotation `image.openshift.io/triggers` | Built-in `triggers` field |
| Lifecycle hooks (pre/mid/post) | ❌ | ✅ |
| Status | ✅ Recommended | ⚠️ Deprecated |
| Portable to plain Kubernetes | ✅ | ❌ |

**Rule:** if a tutorial says `oc rollout latest dc/...`, translate it to `oc rollout restart deploy/...`. Use Deployment.

---

## **3. Anatomy of a Deployment (the `landing-app` Example)**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: landing-app
  labels:
    app: landing-app
  annotations:
    image.openshift.io/triggers: >-
      [{"from":{"kind":"ImageStreamTag","name":"landing-app:latest"},
        "fieldPath":"spec.template.spec.containers[?(@.name==\"landing-app\")].image"}]
spec:
  replicas: 1
  selector:
    matchLabels:
      app: landing-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: landing-app
    spec:
      containers:
        - name: landing-app
          image: landing-app:latest
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef: { name: landing-config }
            - secretRef:    { name: landing-secret, optional: true }
          readinessProbe:
            httpGet: { path: /, port: 8080 }
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /, port: 8080 }
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests: { cpu: 50m,  memory: 128Mi }
            limits:   { cpu: 500m, memory: 256Mi }
```

### **Line-by-line**

| Section | What it does |
|---|---|
| `metadata.annotations.image.openshift.io/triggers` | Roll out automatically when the ImageStreamTag changes |
| `replicas: 1` | One pod (raise for availability) |
| `selector.matchLabels` | Which pods belong to this Deployment (**must match** `template.labels`) |
| `strategy.RollingUpdate` | Replace pods gradually |
| `containerPort: 8080` | Port the app listens on (OpenShift images use 8080, not 80) |
| `envFrom` | Load all keys from a ConfigMap and Secret as environment variables |
| `optional: true` | The pod starts even if the Secret doesn't exist yet |
| `readinessProbe` | "Send traffic only when ready" |
| `livenessProbe` | "Restart if stuck" |
| `resources` | Scheduling and limits, and required if the project has quotas |

### **What the sample app proves**
`server.js` returns `APP_MESSAGE` from `/api/info`. The ConfigMap `landing-config` sets `APP_MESSAGE`. Change the ConfigMap, restart the pods, and the page changes without a rebuild.

---

## **4. Image Triggers (OpenShift's Special Feature)**

### **The Problem**

In Kubernetes, a new image `app:latest` does **not** restart pods. You must change the tag or run `kubectl rollout restart`.

### **The OpenShift Solution**

An **ImageStream** tracks the image. The annotation `image.openshift.io/triggers` tells OpenShift: *"when `landing-app:latest` points to a new image, update this container's image and roll out."*

```
git push → Build → ImageStream landing-app:latest → new digest
                                      │ (trigger)
                                      ▼
                  Deployment's container image updated → rolling update
```

### **Parts of the annotation**

```json
[{
  "from": { "kind": "ImageStreamTag", "name": "landing-app:latest" },
  "fieldPath": "spec.template.spec.containers[?(@.name==\"landing-app\")].image"
}]
```

| Key | Meaning |
|---|---|
| `from` | Which ImageStreamTag to watch |
| `fieldPath` | Which container's `image` field to rewrite |

### **Setting it with a command**

```bash
oc set triggers deploy/landing-app --from-image=landing-app:latest -c landing-app
oc set triggers deploy/landing-app          # show
oc set triggers deploy/landing-app --manual # pause automatic rollouts
oc set triggers deploy/landing-app --auto   # resume
```

### **`lookupPolicy.local: true`**
In `imagestream.yaml`, this lets the Deployment write `image: landing-app:latest` (short name) and have it resolved through the ImageStream, without a registry hostname.

---

## **5. Rollout Strategies**

### **5.1 RollingUpdate (default)**

New pods start, old ones stop gradually, so **there's no downtime**.

```
Before:  [v1] [v1] [v1] [v1]
Step 1:  [v1] [v1] [v1] [v1] [v2]            (maxSurge: one extra)
Step 2:  [v1] [v1] [v1] [v2] [v2]            (old removed when new is Ready)
...
After:   [v2] [v2] [v2] [v2]
```

| Setting | Meaning | Example (4 replicas, 25%) |
|---|---|---|
| `maxSurge` | Extra pods allowed above `replicas` | 1 extra pod |
| `maxUnavailable` | Pods that may be unavailable | 1 pod |

**Safest zero-downtime setting:** `maxUnavailable: 0`, `maxSurge: 1`.

> Rolling updates only work correctly if the **readinessProbe** is right, because traffic goes to new pods only once they pass it.

### **5.2 Recreate**

Stop **all** old pods, then start new ones, which means **downtime**. Use it only when two versions must never run together (for example a schema change).

```yaml
strategy:
  type: Recreate
```

### **5.3 Blue/Green and Canary**

Not built into Deployment. On OpenShift you do them with **Routes** (see Topic 5):
- **Blue/green:** two Deployments and Services; switch the Route's `to` service.
- **Canary:** a Route with two backends and weights (for example 90/10). `oc set route-backends landing-app v1=90 v2=10`.

---

## **6. Configuration: ConfigMaps & Secrets**

### **ConfigMap (non-sensitive)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: landing-config
data:
  APP_MESSAGE: "Hello from ConfigMap in Git"
```

### **Secret (sensitive)**

```bash
oc create secret generic landing-secret --from-literal=APP_SECRET=s3cr3t
```

> The repo's `kustomization.yaml` intentionally **does not list the Secret**. Never commit real secrets to Git. (Production: Sealed Secrets, External Secrets, or Vault.)

### **Three ways to consume config**

| Method | YAML | Updates when changed? |
|---|---|---|
| All keys as env vars | `envFrom: configMapRef` (what `landing-app` uses) | ❌ Needs a pod restart |
| One key as an env var | `env: valueFrom: configMapKeyRef` | ❌ Needs a restart |
| Mounted as files | `volumes` + `volumeMounts` | ✅ Eventually updates the files (the app must re-read them) |

### **Applying a change**

```bash
oc edit configmap landing-config            # change APP_MESSAGE
oc rollout restart deploy/landing-app       # env vars are read at start
oc rollout status deploy/landing-app
curl -s https://$(oc get route landing-app -o jsonpath='{.spec.host}')/api/info
```

### **Quick env management**

```bash
oc set env deploy/landing-app --list
oc set env deploy/landing-app LOG_LEVEL=debug          # adds a plain env var
oc set env deploy/landing-app --from=configmap/landing-config
oc set env deploy/landing-app --from=secret/landing-secret
```

---

## **7. Health Probes**

| Probe | Question | On failure |
|---|---|---|
| **readiness** | Can this pod receive traffic now? | Removed from the Service endpoints (not restarted) |
| **liveness** | Is it stuck? | Container restarted |
| **startup** | Has the slow app finished starting? | Delays liveness/readiness until it passes |

### **Types**

```yaml
readinessProbe:
  httpGet: { path: /healthz, port: 8080 }     # HTTP 200–399 = success
# or
  tcpSocket: { port: 8080 }
# or
  exec: { command: ["cat", "/tmp/ready"] }
```

### **Tuning**

| Field | Meaning |
|---|---|
| `initialDelaySeconds` | Wait before the first check |
| `periodSeconds` | How often |
| `timeoutSeconds` | Per-check timeout |
| `failureThreshold` | Consecutive failures before acting |

### **Rule of thumb**
- **Liveness** should be lenient (so you don't restart-loop under load).
- **Readiness** should reflect "can serve real requests" (including dependencies if you want).
- The sample app also has `/healthz`, which is a better probe target than `/`.

```bash
oc set probe deploy/landing-app --readiness --get-url=http://:8080/healthz --initial-delay-seconds=5
```

---

## **8. Resources (Requests & Limits)**

```yaml
resources:
  requests: { cpu: 50m,  memory: 128Mi }   # reserved; used for scheduling
  limits:   { cpu: 500m, memory: 256Mi }   # hard ceiling
```

| | Request | Limit |
|---|---|---|
| CPU | Guaranteed share | Throttled above it |
| Memory | Guaranteed | **OOMKilled** above it |

### **Why they matter on OpenShift**
- Projects often have a **ResourceQuota** and **LimitRange** (Topic 13). Pods without requests and limits may be **rejected**.
- QoS class: requests = limits → **Guaranteed**, requests < limits → **Burstable**, none → **BestEffort** (first evicted).

```bash
oc set resources deploy/landing-app --requests=cpu=50m,memory=128Mi --limits=cpu=500m,memory=256Mi
oc adm top pod        # live usage (needs metrics; usually available)
```

---

## **9. Scaling & Autoscaling (HPA)**

### **Manual**

```bash
oc scale deploy/landing-app --replicas=3
oc get pods -l app=landing-app -o wide
```

Refresh the page several times and watch the **Pod** name change as the Service load-balances.

### **Horizontal Pod Autoscaler**

```bash
oc autoscale deploy/landing-app --min=2 --max=5 --cpu-percent=70
oc get hpa
```

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: landing-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: landing-app
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 70 }
```

- HPA computes utilization relative to **requests**, so you must set CPU requests.
- Test: `for i in $(seq 1 2000); do curl -s $URL >/dev/null; done` and run `oc get hpa -w`.

---

## **10. Rollouts, History & Rollback**

### **Under the hood**

```
Deployment landing-app
   ├── ReplicaSet landing-app-7d9f  (current, 3 pods)
   ├── ReplicaSet landing-app-5c4a  (previous, 0 pods)
   └── ReplicaSet landing-app-2b1c  (older, 0 pods)
```

Each change to the **pod template** (image, env, resources...) creates a new ReplicaSet. Scaling doesn't.

### **Commands**

```bash
oc rollout status deploy/landing-app          # watch progress
oc rollout history deploy/landing-app         # revisions
oc rollout history deploy/landing-app --revision=2
oc rollout undo deploy/landing-app            # back to the previous revision
oc rollout undo deploy/landing-app --to-revision=1
oc rollout restart deploy/landing-app         # new pods, same spec
oc rollout pause deploy/landing-app           # batch several edits
oc rollout resume deploy/landing-app
```

### **Typical flows**

| Situation | Action |
|---|---|
| New build finished | Nothing (the image trigger rolls it out) |
| Changed ConfigMap | `oc rollout restart deploy/landing-app` |
| Bad release | `oc rollout undo deploy/landing-app` |
| Several edits at once | `pause` → edit → `resume` |

### **Rollback caveat**
`undo` reverts the pod template, but with an image trigger active the next build re-triggers a rollout. To hold a rollback, run `oc set triggers deploy/landing-app --manual` first.

---

## **11. Services & Routes Recap (the Whole Stack)**

### **Service**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: landing-app
spec:
  type: ClusterIP
  selector:
    app: landing-app          # must match the pod labels
  ports:
    - name: 8080-tcp
      port: 8080
      targetPort: 8080
```

### **Route**

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: landing-app
spec:
  to:
    kind: Service
    name: landing-app
  port:
    targetPort: 8080-tcp      # the Service port NAME
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### **Checking the chain when the site is down**

```bash
oc get route landing-app            # host?
oc get svc landing-app              # exists?
oc get endpoints landing-app        # any pod IPs? (empty = selector/readiness problem)
oc get pods -l app=landing-app      # Running and READY 1/1?
oc logs deploy/landing-app
```

The most common bug is a Service `selector` or `targetPort` that doesn't match the pods or the Route (your git history has a "Fixed service" commit for this).

---

## **12. Kustomize: Deploy Everything in One Command**

Your `kustomization.yaml` lists all manifests:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - imagestream.yaml
  - buildconfig.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - route.yaml
```

```bash
cd Openshift/sample-app/Deployment
oc apply -k .                       # create or update everything
oc get all,bc,is,route
oc delete -k .                      # tear it all down
oc kustomize .                      # preview rendered YAML
```

### **Why this matters**
- **Declarative:** the repo is the source of truth, which is the base for GitOps (Topic 20).
- **Repeatable:** the same command works in any project.
- **Order:** the first build starts from the BuildConfig's `ConfigChange` trigger, then the Deployment rolls out once the image exists.

### **First-time sequence**

```bash
oc create secret generic landing-secret --from-literal=APP_SECRET=demo
oc apply -k .
oc logs -f bc/landing-app           # build
oc rollout status deploy/landing-app
oc get route landing-app
```

> The Deployment may sit in `ImagePullBackOff`/waiting until the **first build** pushes `landing-app:latest`. Once the image exists, the trigger fixes it.

---

## **13. `oc new-app` and Import from Git**

Shortcuts that generate the same objects:

```bash
# from source (S2I)
oc new-app nodejs~https://github.com/SanthaprakashMahendran/Landing-Zone.git \
   --context-dir=Openshift/sample-app --name=hello

# from an existing image
oc new-app --image=quay.io/myorg/app:1.0 --name=app

# preview without creating
oc new-app nodejs~https://... --dry-run -o yaml
```

| Approach | Good for | Weakness |
|---|---|---|
| `oc new-app` / Import from Git | Quick start, learning | Hidden defaults, harder to review |
| **Manifests + Kustomize (your approach)** | Real projects, GitOps | You write more YAML |

Tip: run `oc new-app ... --dry-run -o yaml` to learn the generated YAML, then keep the parts you want.

---

## **14. Troubleshooting**

| Symptom | Check | Likely cause |
|---|---|---|
| Pod `ImagePullBackOff` | `oc describe pod` | Image doesn't exist yet (build not finished) or wrong name |
| Pod `CrashLoopBackOff` | `oc logs <pod> --previous` | App crash, wrong start command, missing env |
| Pod `Pending` | `oc describe pod` → Events | Quota exceeded or no capacity |
| `Error creating: pods ... is forbidden: ... exceeded quota` | `oc get quota`, `oc describe quota` | Quota (Topic 13) or no resource requests |
| Pod starts, then permission errors writing files | `oc exec <pod> -- id` | Random non-root UID (SCC); write only to `/tmp` or a volume |
| App listens on port 80 and fails | Logs | Non-root can't bind below 1024; use 8080 |
| `READY 0/1` forever | Probe path/port | Wrong readiness probe |
| Route shows "Application is not available" | `oc get endpoints` | Service selector or targetPort mismatch, or pods not Ready |
| New build, no rollout | `oc set triggers deploy/...` | Trigger annotation missing or paused |
| ConfigMap changed, app unchanged | | Env vars load at start, so run `oc rollout restart` |

### **Debug order**

```bash
oc get pods
oc describe pod <pod>              # Events at the bottom
oc logs <pod> [--previous]
oc get events --sort-by=.lastTimestamp | tail -15
oc rsh <pod>                       # shell inside
oc debug deploy/landing-app        # copy of the pod with a shell (even if it crashes)
```

---

## **15. Real-World Examples**

### **Example 1: Zero-downtime release**

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```
Plus `replicas: 3` and a correct readiness probe.

### **Example 2: Config change without a rebuild**

```bash
oc patch configmap landing-config -p '{"data":{"APP_MESSAGE":"Updated live"}}'
oc rollout restart deploy/landing-app
```

### **Example 3: Roll back a bad release**

```bash
oc rollout history deploy/landing-app
oc set triggers deploy/landing-app --manual
oc rollout undo deploy/landing-app
oc rollout status deploy/landing-app
```

### **Example 4: Canary with a Route**

```bash
oc new-app ... --name=landing-app-v2
oc set route-backends landing-app landing-app=90 landing-app-v2=10
```

---

## **16. Best Practices**

- ✅ Use **Deployment**, not DeploymentConfig
- ✅ Keep manifests in **Git** and apply with `oc apply -k`
- ✅ Always set **requests and limits**
- ✅ Always set a correct **readinessProbe** (it makes rolling updates safe)
- ✅ Run **2+ replicas** for anything important and spread across nodes
- ✅ Listen on **8080** and don't assume root or a fixed UID
- ✅ Never put secrets in Git
- ✅ Pin image tags (use digests or version tags) outside of dev
- ❌ Don't edit objects in the console only: your Git copy will drift
- ❌ Don't use `latest` tags for production images

---

## **17. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted

| # | Task | Status |
|---|---|---|
| 1 | `cd Openshift/sample-app/Deployment && oc apply -k .` | ✅ |
| 2 | Create the Secret: `oc create secret generic landing-secret --from-literal=APP_SECRET=demo` | ✅ |
| 3 | Follow the first build: `oc logs -f bc/landing-app` | ✅ |
| 4 | `oc rollout status deploy/landing-app` then open the Route | ✅ |
| 5 | Check the page: Pod name, UID, `APP_MESSAGE`, `APP_SECRET set` | ✅ |
| 6 | Change `landing-config`, `oc rollout restart`, confirm the page changes | ✅ |
| 7 | `oc scale deploy/landing-app --replicas=3`, refresh the page, watch the Pod value change | ✅ |
| 8 | Add an HPA: `oc autoscale deploy/landing-app --min=2 --max=4 --cpu-percent=70` | ✅ (metrics permitting) |
| 9 | Edit `index.html`, push, build, and watch the image trigger roll out | ✅ |
| 10 | Break it: set `image: landing-app:nonexistent`, watch `ImagePullBackOff`, then `oc rollout undo` | ✅ |
| 11 | Break the readiness probe path, watch `0/1 READY` and the rolling update **stall safely** | ✅ |
| 12 | `oc get endpoints landing-app` while pods are not Ready vs Ready | ✅ |
| 13 | `oc debug deploy/landing-app` and run `id` | ✅ |

### **Expected learning outcomes**
- You can read every field of a Deployment manifest.
- You know how a Git push becomes a running pod through the image trigger.
- You can roll back and diagnose a failed rollout.

---

## **18. Key Takeaways**

1. Use the standard **Deployment**. DeploymentConfig is deprecated.
2. OpenShift's extra: the **`image.openshift.io/triggers`** annotation links a Deployment to an **ImageStream**, so builds roll out automatically.
3. **RollingUpdate** is the default and gives zero downtime if the **readiness probe** is right.
4. Config changes through `envFrom` need a **restart** to take effect.
5. **Requests/limits** are practically mandatory on OpenShift because of quotas.
6. **Rollback** with `oc rollout undo`, and set triggers to manual to keep it.
7. When a Route shows "not available", check **Endpoints** first.
8. Put all manifests in **Git + Kustomize** and you're ready for GitOps.

### **Common Commands**

```bash
oc apply -k .
oc get deploy,rs,pods,svc,route
oc rollout status|history|undo|restart deploy/landing-app
oc scale deploy/landing-app --replicas=3
oc set triggers|env|resources|probe deploy/landing-app ...
oc describe pod <pod>
oc logs deploy/landing-app
oc debug deploy/landing-app
```

---

**✅ Topic 9 Complete**

When ready, reply:
- ✅ **"Ready for Topic 11"** → Move to: ImageStreams & the Internal Registry
- ❓ **"Need clarification on [section]"**
