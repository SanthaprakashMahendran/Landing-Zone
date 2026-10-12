# **OpenShift Hands-on Lab: One App, Many Concepts**

We deploy one small Node.js website (Express + HTML) ([sample-app/](sample-app/)) and grow it stage by stage.
Each stage maps to a topic in these notes.

Legend: ✅ works in sandbox · ⚠️ may be restricted (verify) · ❌ not possible

| Stage | What we do | Concept | Topic | Sandbox |
|---|---|---|---|---|
| 0 | Install `oc`, log in, check permissions | Access, tokens | 2, 3 | ✅ |
| 1 | Build and deploy from source (S2I) | BuildConfig, ImageStream, Deployment, Service | 3, 9, 10, 11 | ✅ |
| 2 | Expose with a Route, then add TLS | Routes | 5 | ✅ |
| 3 | ConfigMap, Secret, probes, resources | Config and health | 9 | ✅ |
| 4 | Run a root-only image, watch it fail, fix it | SCC | 6 | ✅ |
| 5 | Scale, rolling update, rollback | Deployments | 9 | ✅ |
| 6 | Add a database with a PVC | Storage | 15 | ⚠️ |
| 7 | Quota, LimitRange, NetworkPolicy, RBAC | Governance | 12, 13, 14 | ⚠️ |
| 8 | Rebuild on `git push` (webhook) | Builds | 10 | ✅ |
| 9 | Pipeline with Tekton | CI/CD | 19 | ⚠️ |
| 10 | GitOps with Argo CD | CD | 20 | ⚠️ |

Stages 6 and later depend on what the sandbox lets us install. We'll check each before starting.

---

## **Stage 0: Access** ✅

```bash
brew install openshift-cli
# Console → user menu → Copy login command → Display Token
oc login --token=sha256~xxxx --server=https://api.<cluster-domain>:443
oc whoami
oc project santha-dev
oc auth can-i --list -n santha-dev
oc get is -n openshift | grep -i nodejs      # which Node.js builder images exist
```

**Checkpoint:** you can see your project and a Node.js builder image.

---

## **Stage 1: Build and deploy from source** ✅

The builder is Source-to-Image (S2I). OpenShift detects Node.js from `package.json`, builds an image,
pushes it to the internal registry and deploys it. No Dockerfile needed.

### Option A: from Git (needs the repo to be public)

```bash
oc new-app nodejs~https://github.com/<you>/Landing-Zone.git \
  --context-dir=Openshift/sample-app \
  --name=hello
```

### Option B: from your Mac (no GitHub needed)

```bash
cd Openshift/sample-app
oc new-build --name=hello --binary --image-stream=nodejs
oc start-build hello --from-dir=. --follow
oc new-app hello
```

### Watch it happen

```bash
oc logs -f buildconfig/hello          # S2I build log
oc get build,is,deploy,pod,svc        # everything that was created
oc describe is hello
```

**Questions to answer from the output:**
1. Which objects did `new-app` create that Kubernetes would need you to write by hand?
2. What is the image name, and which registry is it in?
3. What UID is the container running as? (The page shows it in Stage 2.)

---

## **Stage 2: Expose with a Route** ✅

```bash
oc expose svc/hello
oc get route hello
curl http://$(oc get route hello -o jsonpath='{.spec.host}')
```

Then add TLS (edge termination, using the router's wildcard cert):

```bash
oc patch route hello -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'
curl -I http://$(oc get route hello -o jsonpath='{.spec.host}')    # expect a 302 to https
```

**Checkpoint:** the page shows a pod name and a **random UID** (for example `1000760000`). That is SCC in action.

---

## **Stage 3 to 10**

We'll write each stage in this file as we reach it, after checking the sandbox allows it.
Next up is **Stage 3: ConfigMap, Secret, probes, resources**.
