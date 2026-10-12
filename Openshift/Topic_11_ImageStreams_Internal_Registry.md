# **Topic 11: ImageStreams & the Internal Registry ⭐ — Complete Notes**

> **Sandbox practicability:** ✅ Mostly.
> ✅ Create and inspect ImageStreams, tag, import external images, push and pull inside your project.
> ⚠️ Exposing the registry externally (default route) and pruning are admin tasks.

---

## **Table of Contents**
1. Introduction
2. What is an ImageStream?
3. Why ImageStreams Exist
4. ImageStream Objects (IS, Tag, Image)
5. Anatomy (the `landing-app` ImageStream)
6. Internal Registry
7. Importing External Images
8. Tagging & Promotion Between Projects
9. Triggers (Builds & Deployments)
10. Local Lookup & Reference Policy
11. Access Control (Pull/Push Between Projects)
12. Pull Secrets for External Registries
13. Pruning & Storage
14. Troubleshooting
15. Real-World Examples
16. Best Practices
17. Hands-on Lab (Sandbox)
18. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

An **ImageStream** is an OpenShift object that **points to container images** and tracks their history. It's not the image itself, only a named, observable pointer.

**Think of it like:**
```
Kubernetes:   image: quay.io/myorg/app:latest      ← a string; the cluster has no idea when it changes
OpenShift:    ImageStream app:latest               ← an object; OpenShift sees every change and can react
```

---

## **2. What is an ImageStream?**

An ImageStream (`is`) is a **collection of tags**. Each tag points to an immutable image **digest**.

```
ImageStream: landing-app
   ├── tag latest  → sha256:bbb111   (current)
   │                  history: sha256:aaa000
   └── tag v1.0    → sha256:aaa000
```

- The image **data** lives in the registry.
- The ImageStream holds **metadata**: tags, digests, history, where it came from.
- OpenShift **watches** the stream and fires **triggers** when a tag moves.

---

## **3. Why ImageStreams Exist**

### **Problems with plain image references**

| Problem | In plain Kubernetes |
|---|---|
| New image pushed to `app:latest` | The cluster never knows, so pods don't restart |
| Which exact image is running? | Hard to tell if the tag moved |
| Docker Hub rate limits | Each node pulls from the internet |
| Build → deploy automation | You write CI glue |
| Promote dev → prod | Re-tag in an external registry by hand |

### **What ImageStreams give you**

| Feature | Benefit |
|---|---|
| **Change detection** | A tag moving triggers builds and rollouts |
| **History** | Which digests a tag pointed to, and when |
| **Decoupling** | Apps refer to `landing-app:latest`, not a registry URL |
| **Caching/mirroring** | Optionally pull once, serve many times from the internal registry |
| **Promotion** | `oc tag dev/app:latest prod/app:1.0` |
| **Access control** | Project RBAC decides who can pull or push |

---

## **4. ImageStream Objects (IS, Tag, Image)**

| Object | Short | Meaning | Example |
|---|---|---|---|
| **ImageStream** | `is` | The collection | `landing-app` |
| **ImageStreamTag** | `istag` | A named tag in it | `landing-app:latest` |
| **ImageStreamImage** | `isimage` | A specific digest | `landing-app@sha256:bbb...` |
| **Image** | `image` | Cluster-wide image metadata (admin) | `sha256:bbb...` |

```bash
oc get is
oc get istag
oc describe is landing-app
oc get istag landing-app:latest -o yaml
```

### **Full image name**

```
image-registry.openshift-image-registry.svc:5000/santha-dev/landing-app:latest
└────────────────── registry service ────────────┘ └project┘ └ is  ┘ └ tag ┘
```

Pattern: `<registry>/<project>/<imagestream>:<tag>`

---

## **5. Anatomy (the `landing-app` ImageStream)**

Your `imagestream.yaml`:

```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: landing-app
  labels:
    app: landing-app
spec:
  lookupPolicy:
    local: true
```

It's nearly empty. You don't define tags here, because **the BuildConfig fills `landing-app:latest`** every time it builds. Look at the status after a build:

```bash
oc get is landing-app -o yaml
```

```yaml
status:
  dockerImageRepository: image-registry.openshift-image-registry.svc:5000/santha-dev/landing-app
  tags:
    - tag: latest
      items:
        - created: "2026-10-08T10:15:00Z"
          dockerImageReference: image-registry...:5000/santha-dev/landing-app@sha256:bbb...
          image: sha256:bbb...
        - image: sha256:aaa...        # previous build
```

### **Spec with external tags**

```yaml
spec:
  tags:
    - name: "1.0"
      from:
        kind: DockerImage
        name: quay.io/myorg/app:1.0
      importPolicy:
        scheduled: true               # re-check the source periodically
      referencePolicy:
        type: Local                   # pull through the internal registry
```

---

## **6. Internal Registry**

OpenShift ships with an **integrated registry** (managed by the **Image Registry Operator**).

| Fact | Detail |
|---|---|
| Service | `image-registry.openshift-image-registry.svc:5000` (in-cluster only by default) |
| Namespace | `openshift-image-registry` |
| Storage | Backed by object storage (**S3** on AWS/ROSA), configured by the operator |
| Auth | Uses your OpenShift token (no separate user/password) |
| Used by | S2I and Docker builds output, ImageStream pulls |
| External access | Needs a **route** (`default-route`) enabled by an admin |

```bash
oc get pods -n openshift-image-registry          # may be forbidden in sandbox
oc get configs.imageregistry.operator.openshift.io/cluster -o yaml   # admin
```

### **Pushing and pulling from your laptop** (needs the external route ⚠️)

```bash
HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
podman login -u $(oc whoami) -p $(oc whoami -t) $HOST
podman tag myapp $HOST/santha-dev/myapp:1.0
podman push $HOST/santha-dev/myapp:1.0
```

> In the sandbox the default route is probably not exposed. Use **builds** (binary build or Git) to get images in.

---

## **7. Importing External Images**

### **One-time import**

```bash
oc import-image nginx-unprivileged --from=docker.io/nginxinc/nginx-unprivileged:latest --confirm
oc get is,istag
```

### **Keep it in sync**

```bash
oc import-image app --from=quay.io/myorg/app:stable --confirm --scheduled=true
```

`--scheduled` re-checks the source every ~15 minutes, so a new digest upstream moves your tag and fires triggers.

### **Deploy from it**

```bash
oc new-app nginx-unprivileged:latest
```

### **`oc tag` (create or move a tag)**

```bash
oc tag docker.io/nginxinc/nginx-unprivileged:latest nginx:1.0      # external → IS tag
oc tag landing-app:latest landing-app:v1.0                          # alias inside project
oc tag --source=docker quay.io/myorg/app:2 app:2 --scheduled        # scheduled import tag
oc tag landing-app:latest -d                                        # delete a tag
```

### **Why import instead of pulling directly?**
- Cached metadata, so there's no repeated Docker Hub lookup (helps with rate limits)
- Triggers work (a plain external image reference can't trigger anything)
- You get history and a stable local name

---

## **8. Tagging & Promotion Between Projects**

### **The idea**

```
project dev   → landing-app:latest  (every build)
                   │  you test, approve
                   ▼   oc tag dev/landing-app:latest prod/landing-app:1.0
project prod  → landing-app:1.0     (promoted, immutable digest)
```

```bash
oc tag santha-dev/landing-app:latest santha-prod/landing-app:1.0
oc get istag -n santha-prod
```

You promote the **same digest** that was tested, with no rebuild. This is a core OpenShift pattern (and a Tekton/Argo CD step later).

### **Pull permission**
The `prod` project must be allowed to pull from `dev` (section 11).

---

## **9. Triggers (Builds & Deployments)**

ImageStreams power **two** triggers you already met:

| Trigger | Watches | Starts |
|---|---|---|
| **BuildConfig ImageChange** | The **builder** tag, `nodejs:latest` in `openshift` | A rebuild (picks up patched base images) |
| **Deployment annotation** | The **app** tag, `landing-app:latest` | A new rollout |

```
nodejs:latest changes ──▶ BuildConfig rebuilds ──▶ landing-app:latest changes ──▶ Deployment rolls out
```

So **a security fix in the Node.js builder reaches your running pods automatically**. That chain is a main reason to use ImageStreams.

```bash
oc set triggers bc/landing-app
oc set triggers deploy/landing-app
```

---

## **10. Local Lookup & Reference Policy**

### **`lookupPolicy.local: true`**

```yaml
spec:
  lookupPolicy:
    local: true
```

Lets any workload in the project write:

```yaml
image: landing-app:latest        # short name
```

and have it resolved to the ImageStream's digest. Without it a plain Deployment would try `docker.io/library/landing-app:latest` and fail.

### **Reference policy (for imported tags)**

| Policy | Pods pull from | Use |
|---|---|---|
| **Source** | The original registry | Always fresh, depends on the external registry's availability |
| **Local** | The internal registry (mirrored on first pull) | Faster, resilient, avoids rate limits |

---

## **11. Access Control (Pull/Push Between Projects)**

Inside a project, everything works. **Across projects**, grant roles:

| Role | Allows |
|---|---|
| `system:image-puller` | Pull images from a project's ImageStreams |
| `system:image-pusher` | Push images |
| `system:image-builder` | Build and push (given to the `builder` service account) |

### **Let `prod` pull from `dev`**

```bash
# run in (or against) the project that owns the images
oc policy add-role-to-user system:image-puller \
   system:serviceaccount:santha-prod:default -n santha-dev
```

Or allow all authenticated users (use sparingly):

```bash
oc policy add-role-to-group system:image-puller system:authenticated -n santha-dev
```

### **Service accounts you'll see**

| SA | Used for |
|---|---|
| `builder` | Build pods push images to the internal registry |
| `deployer` | (legacy DeploymentConfig) |
| `default` | Pods pull images with it, so give it pull access |

```bash
oc get sa
oc describe sa builder        # shows its dockercfg pull/push secret
```

---

## **12. Pull Secrets for External Registries**

For private registries (Quay, ECR, Docker Hub with credentials):

```bash
oc create secret docker-registry regcred \
  --docker-server=quay.io \
  --docker-username=<user> \
  --docker-password=<token> \
  --docker-email=you@example.com

# Use for pulls by pods
oc secrets link default regcred --for=pull

# Use for imports (oc import-image / oc tag to private source)
oc secrets link default regcred --for=pull
oc import-image app --from=quay.io/myorg/private:1 --confirm
```

For builds that push to an external registry, set `pushSecret` in the BuildConfig `output` section and link the secret to `builder`:

```bash
oc secrets link builder regcred
```

> Cluster-wide pull secret (`openshift-config/pull-secret`) is an admin object, so don't expect to edit it in the sandbox.

---

## **13. Pruning & Storage**

Images pile up: every build adds a layer set.

| What | How it's cleaned |
|---|---|
| Old **Builds** | BuildConfig `successfulBuildsHistoryLimit` and `failedBuildsHistoryLimit` |
| Old ImageStream **tag history** | ImageStream keeps a limited history |
| Unused **images and layers** in the registry | **Image pruner**, a scheduled job run by the Image Registry Operator (admin) |
| Manual | `oc adm prune images --keep-tag-revisions=3 --keep-younger-than=60m --confirm` (admin) |

### **Quota on images**

Projects can be limited with a **LimitRange** (`openshift.io/ImageStream` type) and **ResourceQuota** (`openshift.io/imagestreams`). See Topic 13.

```bash
oc describe quota        # look for openshift.io/imagestreams
```

---

## **14. Troubleshooting**

| Symptom | Check | Likely cause |
|---|---|---|
| `ImagePullBackOff` on `landing-app:latest` | `oc get istag landing-app:latest` | No build has produced the tag yet |
| `unauthorized: authentication required` | `oc describe pod` Events | Cross-project pull without `system:image-puller`, or missing pull secret |
| Deployment resolves to `docker.io/library/...` | `oc get is -o yaml` | `lookupPolicy.local` missing |
| Build can't push | `oc logs build/...` | `builder` SA lacks access, or the output ImageStream name is wrong |
| `manifest unknown` | | Tag or digest doesn't exist anymore (pruned) |
| `toomanyrequests` from Docker Hub | | Rate limit; import to an ImageStream, use `referencePolicy: Local`, or use a registry with credentials |
| Tag doesn't update after a push | `oc describe is` | Import not scheduled (external tags don't auto-refresh) |
| Rollout doesn't fire on new image | `oc set triggers deploy/...` | Annotation missing or paused |

### **Debug**

```bash
oc describe is landing-app          # last import status, errors
oc get istag
oc get events --sort-by=.lastTimestamp | tail
oc get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

---

## **15. Real-World Examples**

### **Example 1: Which image is actually running?**

```bash
oc get deploy landing-app -o jsonpath='{.spec.template.spec.containers[0].image}'
# image-registry...:5000/santha-dev/landing-app@sha256:bbb...
oc get is landing-app -o jsonpath='{.status.tags[0].items[*].image}'
```

If the digest matches, the running pod is the latest build.

### **Example 2: Run a public image safely on OpenShift**

```bash
oc import-image nginx-unprivileged --from=docker.io/nginxinc/nginx-unprivileged:stable --confirm
oc new-app nginx-unprivileged:stable --name=web
oc expose svc/web
```

(A regular `nginx` image fails because it needs root. See Topic 6.)

### **Example 3: Promote dev → test**

```bash
oc tag santha-dev/landing-app:latest santha-test/landing-app:rc1
oc policy add-role-to-user system:image-puller system:serviceaccount:santha-test:default -n santha-dev
```

### **Example 4: Keep a base image fresh**

```bash
oc import-image ubi9-minimal --from=registry.access.redhat.com/ubi9/ubi-minimal:latest --confirm --scheduled=true
```

---

## **16. Best Practices**

- ✅ Reference images through **ImageStreams**, not raw registry URLs, so triggers work
- ✅ Set `lookupPolicy.local: true` when plain Deployments use short image names
- ✅ **Promote the same digest** across environments, with no rebuilds
- ✅ Use meaningful tags (`1.0`, `rc1`) for releases, and `latest` only in dev
- ✅ Use `--scheduled` imports only for images you trust to move
- ✅ Set `*BuildsHistoryLimit` so old builds don't eat storage
- ✅ Give only the **needed** SAs `image-puller`
- ❌ Don't push secrets into images
- ❌ Don't rely on the internal registry as an archive, because it's a working registry that gets pruned

---

## **17. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted

| # | Task | Status |
|---|---|---|
| 1 | `oc get is,istag` and `oc describe is landing-app` | ✅ |
| 2 | Find the full image reference and digest of the running pod | ✅ |
| 3 | Run another build, then confirm the digest changed and the tag history shows 2 entries | ✅ |
| 4 | `oc get is -n openshift` and list the builder images | ✅ |
| 5 | `oc import-image nginx-unprivileged --from=docker.io/nginxinc/nginx-unprivileged:stable --confirm` | ✅ |
| 6 | Deploy it with `oc new-app nginx-unprivileged:stable` and expose a Route | ✅ |
| 7 | Create a tag alias: `oc tag landing-app:latest landing-app:v1` | ✅ |
| 8 | Remove `lookupPolicy`, redeploy, and watch the pull fail. Restore it. | ✅ |
| 9 | `oc describe sa builder` and `oc describe sa default` | ✅ |
| 10 | Create a second project and promote an image with `oc tag`, then grant `system:image-puller` | ⚠️ (project creation may be limited) |
| 11 | Enable the registry route and push from `podman` | ❌ admin |

### **Expected learning outcomes**
- You can explain IS vs ISTag vs digest.
- You can trace builder-image change → build → ImageStream → rollout.
- You can import external images and give another project pull access.

---

## **18. Key Takeaways**

1. **An ImageStream is a pointer with history**, not the image itself.
2. **Tags point to digests.** The digest is the real identity.
3. The **internal registry** is built in (backed by S3 on ROSA) and uses your OpenShift token.
4. **Triggers** make builds and deployments react to image changes.
5. **`oc tag` promotes** the same digest across projects with no rebuild.
6. **`lookupPolicy.local: true`** lets plain workloads use short ImageStream names.
7. Cross-project access needs **`system:image-puller`**, and private registries need a **pull secret** linked to a service account.
8. External image tags **don't auto-update** unless imported with `--scheduled`.

### **Common Commands**

```bash
oc get is,istag
oc describe is <name>
oc import-image <name> --from=<registry/image:tag> --confirm [--scheduled]
oc tag <source> <is>:<tag>
oc policy add-role-to-user system:image-puller system:serviceaccount:<proj>:default -n <owner-proj>
oc secrets link default <secret> --for=pull
oc set triggers deploy/<name>
```

---

**✅ Topic 11 Complete**

When ready, reply:
- ✅ **"Ready for Topic 12"** → Move to: RBAC, Users, Groups & OAuth Identity Providers
- ❓ **"Need clarification on [section]"**
