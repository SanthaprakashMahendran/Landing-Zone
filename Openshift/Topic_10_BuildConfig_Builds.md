# **Topic 10: BuildConfig & Builds (Source-to-Image) — Complete Notes**

> **Sandbox practicability:** ✅ Fully. Builds run inside your own project (`santha-dev`).
> Only cluster-wide build settings (allowed image sources, build defaults) are off limits.

---

## **Table of Contents**
1. Introduction
2. What is a BuildConfig?
3. BuildConfig vs Build
4. BuildConfig Anatomy (YAML Walkthrough)
5. Build Strategies
6. Source-to-Image (S2I) in Detail
7. Build Triggers
8. Build Inputs: Git, Binary, Dockerfile
9. Private Git Repositories
10. Output: ImageStreams
11. Connecting Builds to Deployments
12. Environment, Resources & Limits
13. Build Lifecycle & Status
14. Commands Reference
15. Real-World Example (Node.js "hello" App)
16. Troubleshooting
17. BuildConfig vs Alternatives (Dockerfile, Shipwright, Tekton)
18. Hands-on Lab (Sandbox)
19. Key Takeaways

---

## **1. Introduction**

### **The Kubernetes Problem**

Kubernetes **runs** images but does not **build** them. Your usual flow is:

```
write Dockerfile → docker build → docker push → edit Deployment image → kubectl apply
```

You need Docker on a laptop or CI, an external registry, and a pipeline to glue it together.

### **The OpenShift Answer**

OpenShift builds images **inside the cluster**:

```
git push ──▶ BuildConfig ──▶ Build pod ──▶ ImageStream ──▶ Deployment rolls out
```

No local Docker, no external registry (the internal one is used), and no Dockerfile if you use S2I.

### **Objects Involved**

| Object | Role | Kubernetes equivalent |
|---|---|---|
| **BuildConfig (bc)** | The recipe | none |
| **Build** | One run of the recipe | none (closest: a Job) |
| **ImageStream (is)** | Pointer to the built image | none |
| **Builder image** | Tool image that does the build (for example Node.js) | none |

---

## **2. What is a BuildConfig?**

A **BuildConfig** describes **how to build an image**: where the source is, which strategy to use, where to push the result, and what triggers a rebuild.

API: `build.openshift.io/v1`, kind `BuildConfig`.

```
┌──────────────────────── BuildConfig: hello ────────────────────────┐
│  source   → https://github.com/<you>/openshift-hello.git (main)    │
│  strategy → Source (S2I) with nodejs builder image                 │
│  output   → ImageStreamTag  hello:latest                           │
│  triggers → ConfigChange, ImageChange, GitHub webhook              │
└────────────────────────────────────────────────────────────────────┘
```

---

## **3. BuildConfig vs Build**

| | BuildConfig | Build |
|---|---|---|
| Meaning | The recipe (desired behaviour) | One execution of it |
| Count | 1 per app | Many (`hello-1`, `hello-2`, ...) |
| Creates | Builds | A temporary **build pod** (`hello-1-build`) |
| Analogy | CronJob | Job |
| Edited by you? | Yes | No (read-only record) |

```
BuildConfig hello
   ├── Build hello-1  ✔ Complete   → hello@sha256:aaa
   ├── Build hello-2  ✔ Complete   → hello@sha256:bbb
   └── Build hello-3  ✖ Failed
```

Each Build keeps: the Git commit used, the log, the start/end time, the output image digest, and the reason for any failure.

---

## **4. BuildConfig Anatomy (YAML Walkthrough)**

A complete example for the sample app:

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: hello
  namespace: santha-dev
spec:
  runPolicy: Serial                    # builds run one at a time
  source:
    type: Git
    git:
      uri: https://github.com/<you>/openshift-hello.git
      ref: main
    contextDir: /                      # sub-folder of the repo to build
  strategy:
    type: Source                       # S2I
    sourceStrategy:
      from:
        kind: ImageStreamTag
        namespace: openshift
        name: nodejs:20-ubi9           # builder image (check: oc get is -n openshift)
      env:
        - name: NPM_MIRROR
          value: ""
  output:
    to:
      kind: ImageStreamTag
      name: hello:latest               # where the result goes
  triggers:
    - type: ConfigChange
    - type: ImageChange
      imageChange: {}
    - type: GitHub
      github:
        secretReference:
          name: hello-github-webhook
  successfulBuildsHistoryLimit: 3
  failedBuildsHistoryLimit: 3
  completionDeadlineSeconds: 1200      # kill builds that take longer than 20 min
  resources:
    limits:
      cpu: "1"
      memory: 1Gi
```

### **Section by section**

| Section | Purpose | Notes |
|---|---|---|
| `runPolicy` | Concurrency | `Serial` (default), `SerialLatestOnly`, `Parallel` |
| `source` | Input | `Git`, `Binary`, `Dockerfile`, `Images` |
| `source.contextDir` | Build a sub-folder | Handy for monorepos (`Openshift/sample-app`) |
| `strategy` | How to build | `Source`, `Docker`, `Custom`, `JenkinsPipeline` |
| `output.to` | Result target | An ImageStreamTag, or a `DockerImage` in an external registry |
| `triggers` | Auto-start | See section 7 |
| `*BuildsHistoryLimit` | Cleanup | Old Builds are deleted automatically |
| `completionDeadlineSeconds` | Timeout | Protects your quota |
| `resources` | Build pod limits | Counts against your project quota |

---

## **5. Build Strategies**

| Strategy | You provide | OpenShift does | Use when |
|---|---|---|---|
| **Source (S2I)** | Source code | Pulls a builder image, runs its `assemble` script, commits an image | You want no Dockerfile (**our case**) |
| **Docker** | A Dockerfile in the repo | Runs a daemonless build (Buildah) | You already have a Dockerfile |
| **Custom** | Your own builder image | Runs it with the Build as input | Special tooling (rare) |
| **Pipeline** | A Jenkinsfile | Starts a Jenkins pipeline | Legacy. Use Tekton instead. |

### **Choosing**

```
Do you already have a Dockerfile you want to keep?
   ├─ Yes → Docker strategy
   └─ No  → Is there an S2I builder for your language (Node, Python, Java, Go, PHP, Ruby, .NET)?
              ├─ Yes → Source strategy (S2I)
              └─ No  → write a Dockerfile
```

### **Quick examples**

```bash
# S2I from Git
oc new-app nodejs~https://github.com/<you>/openshift-hello.git --name=hello

# Docker strategy from Git (needs a Dockerfile in the repo)
oc new-build https://github.com/<you>/openshift-hello.git --strategy=docker --name=hello-docker
```

---

## **6. Source-to-Image (S2I) in Detail**

### **6.1 What S2I does**

```
   ┌─────────────┐   ┌─────────────────┐
   │ Your source │ + │ Builder image   │
   │ (Git repo)  │   │ (nodejs:20-ubi9)│
   └──────┬──────┘   └────────┬────────┘
          └────────┬──────────┘
                   ▼
        assemble script runs in the builder
        (npm install, copy code, ...)
                   ▼
        Result is committed as a NEW image
        (builder + your app, with a run script as CMD)
                   ▼
        Pushed to image-registry...:5000/santha-dev/hello:latest
```

### **6.2 The two S2I scripts**

| Script | Runs | Does |
|---|---|---|
| `assemble` | At build time | Installs dependencies, compiles, puts the app in place |
| `run` | At container start | Starts the app (`npm start` for Node.js) |

Builders ship with defaults. You can override them by adding `.s2i/bin/assemble` or `.s2i/bin/run` to your repo.

### **6.3 How S2I detects the language**

| File in repo | Detected as |
|---|---|
| `package.json` | Node.js |
| `requirements.txt` / `setup.py` | Python |
| `pom.xml` | Java (Maven) |
| `go.mod` | Go |
| `composer.json` | PHP |
| `Gemfile` | Ruby |

Our repo has `package.json` → Node.js builder.

### **6.4 Node.js builder behaviour**

| Behaviour | Detail |
|---|---|
| Install | `npm install --production` (set `NODE_ENV=development` to also install devDependencies) |
| Start | `npm start` (so `package.json` needs a `start` script, ours has one) |
| Port | App should listen on **8080** (the image exposes 8080) |
| Env knobs | `NPM_RUN`, `NPM_MIRROR`, `NODE_ENV`, `DEV_MODE` |

### **6.5 Why S2I is nice**

- **No Dockerfile to maintain**, and developers don't need container expertise.
- **Faster rebuilds** with incremental builds (`incremental: true` reuses `node_modules`).
- **Security patching**: when Red Hat updates the Node.js builder, the ImageChange trigger rebuilds your app on the patched base.
- **Non-root by default**: the resulting image runs as an arbitrary non-root UID (see Topic 6, SCC).

---

## **7. Build Triggers**

| Trigger | Fires when | Add with |
|---|---|---|
| **ConfigChange** | The BuildConfig is created or changed | on by default with `new-app` |
| **ImageChange** | The **builder image** tag gets a new image | on by default |
| **GitHub webhook** | GitHub sends a push event | `oc set triggers bc/hello --from-github` |
| **GitLab / Bitbucket webhook** | Same, for those hosts | `--from-gitlab`, `--from-bitbucket` |
| **Generic webhook** | Any `curl` to the URL | `oc set triggers bc/hello --from-webhook` |
| **Manual** | You run it | `oc start-build hello` |

### **7.1 Setting up a GitHub webhook**

```bash
# 1. add the trigger (generates a secret)
oc set triggers bc/hello --from-github

# 2. get the URL
oc describe bc hello | grep -A1 -i "webhook github"
#  → https://api.<cluster>:443/apis/build.openshift.io/v1/namespaces/santha-dev/buildconfigs/hello/webhooks/<secret>/github
```

Then in GitHub: **Repo → Settings → Webhooks → Add webhook**
- **Payload URL:** the URL above (replace `<secret>` with the real secret, `oc get bc hello -o yaml`)
- **Content type:** `application/json`
- **Events:** Just the push event

Now every `git push` starts a new build.

> ⚠️ **Sandbox:** the webhook goes to the cluster's API endpoint. If the sandbox API isn't reachable from the public internet, GitHub can't call it. In that case use `oc start-build` manually (and you'll learn the real fix with Tekton in a later topic).

### **7.2 Image change trigger**

The trigger watches `nodejs:20-ubi9` in the `openshift` namespace. When Red Hat publishes a patched image, your Build starts automatically.

### **7.3 Disabling triggers**

```bash
oc set triggers bc/hello --remove-all
oc set triggers bc/hello --from-config --auto=false   # keep but not auto
```

---

## **8. Build Inputs: Git, Binary, Dockerfile**

### **8.1 Git source (most common)**

```bash
oc new-app nodejs~https://github.com/<you>/openshift-hello.git#main --name=hello
```

`#main` selects a branch (or tag or commit). Use `--context-dir=sub/dir` for a sub-folder.

### **8.2 Binary build (code from your laptop or CI)**

```bash
oc new-build --name=hello --binary --image-stream=nodejs
oc start-build hello --from-dir=. --follow       # upload a folder
oc start-build hello --from-archive=app.tar.gz   # upload an archive
oc start-build hello --from-file=app.jar         # upload one file
oc new-app hello
```

No Git needed. Good for quick tests and CI systems that already built the artifact.

### **8.3 Inline Dockerfile**

```yaml
source:
  type: Dockerfile
  dockerfile: |
    FROM registry.access.redhat.com/ubi9/nodejs-20-minimal
    COPY . .
    RUN npm install
    CMD ["npm","start"]
```

### **8.4 Using a specific commit**

```bash
oc start-build hello --commit=<sha>
```

---

## **9. Private Git Repositories**

The build pod needs credentials to clone a private repo. This is what failed earlier when the cluster tried to clone the private `Landing-Zone` repo.

### **9.1 HTTPS with a token (GitHub PAT)**

```bash
oc create secret generic repo-auth \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=<github-user> \
  --from-literal=password=<personal-access-token>

oc set build-secret --source bc/hello repo-auth
```

### **9.2 SSH deploy key**

```bash
ssh-keygen -t ed25519 -f ./deploy_key -N ""      # add deploy_key.pub to GitHub → repo → Deploy keys
oc create secret generic repo-ssh \
  --type=kubernetes.io/ssh-auth --from-file=ssh-privatekey=./deploy_key
oc set build-secret --source bc/hello repo-ssh
# use git@github.com:<you>/<repo>.git as the URI
```

### **9.3 Rule**
Use a **token with the least permissions** (read-only on one repo) and never put it in the BuildConfig URL.

---

## **10. Output: ImageStreams**

A build's output is normally an **ImageStreamTag**:

```yaml
output:
  to:
    kind: ImageStreamTag
    name: hello:latest
```

```
ImageStream: hello
   └── tag latest → sha256:bbb (current)
        history   → sha256:aaa (previous)
```

- The image lives in the internal registry at `image-registry.openshift-image-registry.svc:5000/santha-dev/hello`.
- Deployments reference the ImageStream, and a new image can trigger a rollout.
- You can also push to an external registry:

```yaml
output:
  to:
    kind: DockerImage
    name: quay.io/<you>/hello:1.0
  pushSecret:
    name: quay-push-secret
```

(ImageStreams are covered in depth in Topic 11.)

---

## **11. Connecting Builds to Deployments**

`oc new-app` and **Import from Git** wire this for you:

```
BuildConfig ─▶ ImageStream hello:latest ─▶ Deployment hello (image trigger)
```

The Deployment carries an annotation so a new image rolls out automatically:

```yaml
metadata:
  annotations:
    image.openshift.io/triggers: >-
      [{"from":{"kind":"ImageStreamTag","name":"hello:latest"},
        "fieldPath":"spec.template.spec.containers[?(@.name==\"hello\")].image"}]
```

Add or inspect it yourself:

```bash
oc set triggers deploy/hello                                    # show
oc set triggers deploy/hello --from-image=hello:latest -c hello # add
```

**Result:** `git push` → Build → new image → pods roll to the new version with no manual step.

---

## **12. Environment, Resources & Limits**

### **12.1 Build-time environment**

```bash
oc set env bc/hello NODE_ENV=production        # persistent
oc start-build hello --env=NPM_MIRROR=https://registry.npmjs.org   # one run only
oc set env bc/hello --list
```

> These are available while building. Runtime variables belong on the Deployment (`oc set env deploy/hello APP_MESSAGE=hi`).

### **12.2 Resources**

```bash
oc set resources bc/hello --limits=cpu=1,memory=1Gi --requests=cpu=200m,memory=512Mi
```

The build pod counts against your project's ResourceQuota (Topic 13). In a sandbox, a heavy build can fail with a quota error.

### **12.3 Build history and cleanup**

```yaml
successfulBuildsHistoryLimit: 3
failedBuildsHistoryLimit: 3
```

Old builds beyond the limits are pruned automatically.

---

## **13. Build Lifecycle & Status**

```
New → Pending → Running → Complete
                     ├──→ Failed     (build script error)
                     ├──→ Error      (platform problem)
                     └──→ Cancelled  (you ran oc cancel-build)
```

| Phase | Meaning |
|---|---|
| New | Created, not yet scheduled |
| Pending | Waiting for the build pod (quota, scheduling, pulling the builder image) |
| Running | Clone, assemble and push in progress |
| Complete | Image pushed successfully |
| Failed | The assemble step or push failed. **Check the log.** |
| Error | Infrastructure problem (for example the pod could not start) |
| Cancelled | Stopped by a user |

### **Under the hood**
The build pod is named `<build>-build` (for example `hello-1-build`) and runs init containers `git-clone`, `manage-dockerfile` and `docker-build`, then exits. It disappears when the build is deleted.

```bash
oc get pods | grep build
oc describe pod hello-1-build
```

---

## **14. Commands Reference**

### **Create**
```bash
oc new-app nodejs~<git-url> --name=hello                # build + deploy
oc new-build <git-url> --name=hello                     # build only (no deployment)
oc new-build --binary --name=hello --image-stream=nodejs
```

### **Run and watch**
```bash
oc start-build hello                    # start
oc start-build hello --follow           # start and stream the log
oc start-build hello --from-dir=.       # binary build
oc start-build hello --env=KEY=VAL      # one-off env
oc logs -f bc/hello                     # log of the latest build
oc logs build/hello-3                   # log of a specific build
oc cancel-build hello-3
```

### **Inspect**
```bash
oc get bc
oc get builds
oc describe bc hello                    # source, strategy, triggers, webhook URLs
oc get bc hello -o yaml
oc get build hello-1 -o jsonpath='{.status.output.to.imageDigest}'
```

### **Change**
```bash
oc set triggers bc/hello --from-github
oc set build-secret --source bc/hello repo-auth
oc set env bc/hello NODE_ENV=production
oc set resources bc/hello --limits=cpu=1,memory=1Gi
oc patch bc hello -p '{"spec":{"source":{"git":{"ref":"dev"}}}}'
oc delete bc hello
```

---

## **15. Real-World Example (Node.js "hello" App)**

### **Scenario**
Deploy the sample Node.js website, change it, and watch the pipeline from Git to running pods.

### **Step 1: Create (what Import from Git already did)**

```bash
oc new-app nodejs~https://github.com/<you>/openshift-hello.git --name=hello
oc expose svc/hello
```

Created: BuildConfig `hello`, ImageStream `hello`, Deployment `hello`, Service `hello`, Build `hello-1`, then the pod and Route.

### **Step 2: Inspect the recipe**

```bash
oc get bc hello -o yaml | less
```

Find `source.git.uri`, `strategy.sourceStrategy.from`, `output.to` and `triggers`.

### **Step 3: Make a change**

Edit `public/index.html` (for example change the heading), then:

```bash
git add . && git commit -m "Update heading" && git push
oc start-build hello --follow          # or let the webhook do it
```

### **Step 4: Watch the rollout**

```bash
oc get builds                          # hello-2 Complete
oc get is hello                        # new digest
oc rollout status deploy/hello         # new pod replaces the old one
oc get pods
```

Refresh the Route URL. The new heading is live.

### **Step 5: Roll back if needed**

```bash
oc rollout undo deploy/hello           # previous ReplicaSet (previous image)
```

### **What you proved**
`git push` → BuildConfig → Build → ImageStream → Deployment → new pods, all in-cluster.

---

## **16. Troubleshooting**

| Symptom | Likely cause | Fix |
|---|---|---|
| `fatal: Authentication failed` / `Repository not found` in the log | Private repo, no source secret | Section 9, or make the app repo public |
| Build stuck in **Pending** | Quota exceeded, or no node capacity | `oc describe build hello-1`, `oc get quota`, lower build `resources` |
| `npm ERR!` in the log | Dependency or network problem | Fix `package.json`, set `NPM_MIRROR` |
| `error: build error: ... no such image nodejs` | Builder ImageStream missing | `oc get is -n openshift \| grep nodejs`, use an existing tag |
| Build **Complete** but pod `CrashLoopBackOff` | App fails at start (no `start` script, wrong port) | `oc logs deploy/hello`, check `npm start` and port **8080** |
| Build passes, site unchanged | Deployment didn't roll out | `oc set triggers deploy/hello`, then `oc rollout status` |
| Webhook never fires | Cluster API not reachable from GitHub, or the wrong secret | Check GitHub → Webhooks → Recent Deliveries |
| `Push failed` | Registry or ImageStream permission problem | `oc describe build`, check the `output.to` name |
| Build killed after 20 min | `completionDeadlineSeconds` hit | Raise it, or reduce build work |

### **Debugging order**
```bash
oc get builds                      # status?
oc logs build/<name>               # why?
oc describe build <name>           # events, reason
oc get events --sort-by=.lastTimestamp | tail -20
```

---

## **17. BuildConfig vs Alternatives (Dockerfile, Shipwright, Tekton)**

| Option | Builds how | Where it runs | Status |
|---|---|---|---|
| **BuildConfig** | S2I / Docker | In-cluster | Stable, widely used, no new features |
| **Builds for Red Hat OpenShift (Shipwright)** | Buildah / S2I / Buildpacks | In-cluster | The strategic replacement |
| **OpenShift Pipelines (Tekton)** | Any steps you define | In-cluster | Full CI/CD (Topic 19) |
| **GitHub Actions / external CI + registry** | Any | Outside | Common for company pipelines |

**Rule of thumb:** use BuildConfig to learn builds and for quick app deployment. Real pipelines should use Tekton or Shipwright.

---

## **18. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted

| # | Task | Status |
|---|---|---|
| 1 | `oc get bc,builds,is` and read the output | ✅ |
| 2 | `oc get bc hello -o yaml` and identify source, strategy, output and triggers | ✅ |
| 3 | `oc logs build/hello-1` and find the clone, `npm install` and push steps | ✅ |
| 4 | Change the heading in `index.html`, push, then `oc start-build hello --follow` | ✅ |
| 5 | Compare `oc get is hello -o yaml` before and after (the tag moves to a new digest) | ✅ |
| 6 | Confirm the Deployment rolled out: `oc rollout status deploy/hello` | ✅ |
| 7 | Break it on purpose: add a bad dependency to `package.json`, build, read the failure | ✅ |
| 8 | Fix it, rebuild, then use `oc rollout undo` to see what a rollback does | ✅ |
| 9 | Do a binary build: `oc new-build --binary --name=hello-bin --image-stream=nodejs` then `oc start-build hello-bin --from-dir=. --follow` | ✅ |
| 10 | Add a GitHub webhook trigger and push | ⚠️ depends on API reachability |
| 11 | `oc cancel-build` a running build | ✅ |
| 12 | Check build limits: `oc get quota`, `oc describe quota` | ✅ |

### **Expected learning outcomes**
- You can read a BuildConfig and explain each section.
- You know the difference between a BuildConfig and a Build.
- You can trace `git push` to running pods.
- You can diagnose a failed build from its log.

---

## **19. Key Takeaways**

1. **BuildConfig = recipe, Build = one run, ImageStream = where the image lands.**
2. **S2I** builds an image from source plus a builder image, so there's no Dockerfile. The language is detected from `package.json`, `pom.xml` and so on.
3. A BuildConfig has four parts: **source, strategy, output, triggers**.
4. **Triggers** automate builds: config change, builder image update, and webhooks.
5. The **ImageStream + Deployment trigger** gives you automatic rollouts after each build.
6. **Private repos** need a source secret (token or SSH key) attached with `oc set build-secret`.
7. Build and run settings are separate: `bc` env for build time, `deploy` env for runtime.
8. BuildConfig is **stable but legacy**; Shipwright and Tekton are the path forward.

### **Topic 10 Complete ✅**
**Next: Topic 9 (Deployments & Rollouts) → Topic 11 (ImageStreams & Registry)**
