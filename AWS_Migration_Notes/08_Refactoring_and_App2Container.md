# Refactoring on AWS: Strangler Pattern, Refactor Spaces & App2Container

---

## Table of Contents
1. What Refactoring Means
2. When to Refactor (and When Not To)
3. Refactoring Targets (Where the App Goes)
4. The Strangler Fig Pattern
5. AWS Migration Hub Refactor Spaces
6. Other Refactoring Patterns
7. AWS App2Container (A2C)
8. App2Container Workflow (Step by Step)
9. Containers Landing Choices (ECS, EKS, OpenShift/ROSA)
10. Database Refactoring
11. Modernization Roadmap Example
12. Assignment 6: App2Container (Optional, Step by Step)
13. Troubleshooting
14. Key Takeaways

> **Availability warning:** AWS changes its migration/modernization service lineup over time. Some services here (**Migration Hub Refactor Spaces**, **App2Container**) may be changed, limited for new customers, or replaced by newer tools (for example AWS Transform for modernization). **Check each service's current status in the AWS documentation before building a plan on it.** The patterns and concepts below don't depend on any one tool.

---

## 1. What Refactoring Means

**Refactor / Re-architect** = change the application's design to use cloud-native capabilities (scale, managed services, resilience, faster delivery).

```
Rehost:     same app, new place (EC2)
Replatform: same app, a few managed services (RDS)
Refactor:   NEW architecture (containers, serverless, microservices, managed everything)
```

It is the **highest effort and highest benefit** of the 6 Rs (see `01_MAP_Framework_and_6Rs.md`).

---

## 2. When to Refactor (and When Not To)

### Refactor when

| Reason | Example |
|---|---|
| The app needs **scale or elasticity** | Seasonal 10× traffic |
| **Release speed** is blocked by the monolith | Every change needs a full regression |
| **Licensing cost** is huge | Oracle/SQL Server/application server licenses |
| **Unsupported technology** | End-of-life OS/runtime that can't be upgraded in place |
| The business has a **strategic reason** | New product line built on this system |

### Don't refactor when

| Reason | Do instead |
|---|---|
| Deadline is a **data center exit** in weeks | Rehost now, refactor later |
| The app is **stable and rarely changed** | Rehost/replatform |
| **No tests** and no one knows the code | Build tests/observability first, or retain/retire |
| No clear business benefit | Don't |

> **Rule of thumb:** *rehost first, refactor selectively.* Typically only 5–15% of applications are worth a real refactor.

---

## 3. Refactoring Targets (Where the App Goes)

| Target | What changes | Good for | Effort |
|---|---|---|---|
| **Containers on ECS/Fargate** | Package the app as containers, with AWS-managed orchestration | Web apps/APIs, simpler operations | Medium |
| **Containers on EKS** | Kubernetes on AWS | Teams with Kubernetes skills, portability | Medium–high |
| **OpenShift (ROSA)** | Containers on managed OpenShift (see your `Openshift/` notes) | Enterprises standardized on OpenShift, S2I builds, operators | Medium–high |
| **Serverless (Lambda)** | Functions, event-driven | Spiky/event workloads, glue logic (see `AWS_Lambda_Complete_Guide.md`) | High (redesign) |
| **Managed services** | Aurora/DynamoDB, SQS/SNS/EventBridge, S3, Cognito, Step Functions | Replace self-managed components | Medium–high |
| **SaaS** | Replace modules with SaaS | Commodity capabilities | Varies |

```
Typical modernization ladder:
EC2 (rehost) → containers (ECS/EKS/ROSA) → managed DB → serverless/event-driven pieces
```

---

## 4. The Strangler Fig Pattern

You **don't rewrite everything at once**. You **gradually replace** parts of the old system behind a **routing layer**, until the old system can be switched off.

```
                       ┌─────────────────────────┐
 Users ───▶ Routing ──▶│  NEW service A (cloud)  │   ← /orders        (moved)
            layer      ├─────────────────────────┤
 (API Gateway/ALB/     │  NEW service B (cloud)  │   ← /payments      (moved)
  proxy)               ├─────────────────────────┤
                       │  OLD monolith           │   ← everything else (shrinking)
                       └─────────────────────────┘
```

### Steps

```
1. Put a routing layer (facade) in front of the monolith (all traffic goes through it, nothing changes yet)
2. Pick ONE capability (low risk, clear boundary, e.g., "product catalog")
3. Build it as a new service (container/Lambda) with its own data
4. Route that path (/catalog/*) to the new service. Everything else still hits the monolith
5. Verify (canary %, compare results), keep a fast rollback (flip the route back)
6. Repeat for the next capability
7. When the monolith has no traffic → retire it
```

### Why it works

| Benefit | Detail |
|---|---|
| **Low risk** | One slice at a time, easy rollback |
| **Continuous value** | Each slice delivers benefits early |
| **No big-bang rewrite** | Business keeps running |
| **Learn as you go** | Early slices teach the team |

### Related techniques
- **Anti-corruption layer:** a translation layer so the new service doesn't inherit the old model's quirks
- **Branch by abstraction:** introduce an interface in the monolith, swap implementations behind it
- **Database strangling:** new services get their own data store, synced from the old DB until cutover (CDC with DMS!)

---

## 5. AWS Migration Hub Refactor Spaces

> Verify current availability first (see the warning at the top).

**Refactor Spaces** is an AWS service that **sets up the routing layer for the strangler pattern** for you, across accounts, using API Gateway or Application Load Balancer (via Network Load Balancer) as the proxy.

### Concepts

| Concept | Meaning |
|---|---|
| **Environment** | The network/routing boundary, shared across accounts |
| **Application** | The "front door" (proxy) for one app. Owns the routes |
| **Service** | A backend target: the **monolith** or a **new microservice** (Lambda URL or VPC endpoint) |
| **Route** | A mapping of a **path** to a **service**. `Default` route → monolith |

```
Environment
 └─ Application "retail"  (API Gateway proxy)
      ├─ Service "monolith" (EC2/ALB)        ← default route "/"
      ├─ Service "catalog"  (ECS service)    ← route "/catalog/*"
      └─ Service "reviews"  (Lambda)         ← route "/reviews/*"
```

### Flow

```
1. Create the Environment
2. Create the Application (proxy: API Gateway)
3. Register the monolith as a Service, and create the default route
4. Build a new service (for example catalog), then register it
5. Create the route "/catalog/*" → new service
6. Test and shift traffic by route, and roll back by deleting/changing the route
```

> **If Refactor Spaces isn't available to you**, build the same facade yourself with **Amazon API Gateway** or an **ALB with path-based rules** (weighted target groups for canary), or **Route 53 weighted routing**, or on OpenShift **Routes with weights** (Topic 5/9).

---

## 6. Other Refactoring Patterns

| Pattern | Idea | AWS pieces |
|---|---|---|
| **Decompose by domain** | Split the monolith by business capability (orders, payments, catalog) | Services + separate data stores |
| **Event-driven decoupling** | Replace synchronous calls with events | SNS/SQS, EventBridge |
| **Queue-based load leveling** | Absorb spikes with a queue | SQS + workers (ECS/Lambda) |
| **Externalize state** | Move sessions/files out of the app server | ElastiCache, DynamoDB, S3, EFS |
| **12-factor configuration** | Config in the environment, not in files | Parameter Store, Secrets Manager |
| **Strangler for the database** | New service owns the data, synced from the old DB | DMS (CDC), Aurora, DynamoDB streams |
| **API-first** | Wrap legacy behind an API | API Gateway |
| **Observability first** | Logs, metrics, traces before splitting | CloudWatch, X-Ray, OpenTelemetry |

**Prerequisite checklist before decomposing:** automated tests, CI/CD, logging/monitoring, clear module boundaries, and a data ownership plan.

---

## 7. AWS App2Container (A2C)

> Verify current availability first (see the warning at the top).

### What it is
A **command-line tool** that takes **existing Java (Linux/Windows) and .NET (ASP.NET on Windows IIS) applications running on servers** and turns them into **container images + deployment artifacts**, **without rewriting code**.

```
App on VM/server ──(App2Container)──▶ container image + ECS/EKS deployment files + CI/CD pipeline
```

It's a **replatform-to-containers** tool, a "lift and shift into containers", not a rewrite. It's the first rung of the modernization ladder.

### What it produces

| Artifact | Purpose |
|---|---|
| **Dockerfile** | Build instructions for the app container |
| **Container image** (in ECR) | Your app, packaged |
| **ECS task definition / EKS manifests** | Run it on ECS or EKS |
| **CloudFormation templates** | Deploy the infrastructure (cluster/service/ALB) |
| **CI/CD pipeline** (CodePipeline/CodeBuild) optional | Rebuild and redeploy |

### Where it runs

| Mode | Use |
|---|---|
| **On the application server itself** | Single app, simple |
| **Worker machine + app server (remote mode)** | Analyze/containerize from a separate worker over SSH/WinRM, which is less intrusive for production |

### Supported (check current docs)
- **Java:** Tomcat, Spring Boot, JBoss, WebLogic, WebSphere (versions vary), generic JAR/WAR
- **.NET:** ASP.NET (.NET Framework) on IIS → **Windows containers**; .NET Core/5+ → Linux containers

---

## 8. App2Container Workflow (Step by Step)

```
1. init           →  configure (workspace, AWS profile, ECR/S3 settings)
2. inventory      →  list candidate applications running on the server
3. analyze        →  analyze one app: ports, dependencies, config, env, files
4. extract/containerize → build the Dockerfile and image(s)
5. generate app-deployment → produce ECS/EKS deployment artifacts + CloudFormation
6. deploy         →  push the image to ECR and deploy to ECS/EKS (+ optional pipeline)
```

### Commands (outline)

```bash
sudo app2container init                          # first-time setup (workspace, profile, S3 bucket for artifacts)
sudo app2container inventory                     # discover apps; output JSON with app IDs
sudo app2container analyze --application-id java-tomcat-1a2b3c4d
#  → edit analysis.json (ports, environment, files to include, etc.)

sudo app2container containerize --application-id java-tomcat-1a2b3c4d
#  → builds the container image locally

sudo app2container generate app-deployment --application-id java-tomcat-1a2b3c4d
#  → creates CloudFormation + ECS/EKS config, and pushes the image to ECR

sudo app2container deploy                        # (optional) deploy automatically
```

### What to review after `analyze`
- **Ports** the app listens on
- **Files and directories** that must go in the image (and those that are data/state and shouldn't)
- **Environment variables**, **connection strings**, **secrets** (move to Secrets Manager)
- **Dependencies** on other servers (databases, file shares)
- **Session state** (may require sticky sessions or an external session store)

### After containerizing (what A2C doesn't do for you)

| Concern | Action |
|---|---|
| **State** (local files/sessions) | Move to EFS/S3/ElastiCache/DB |
| **Secrets** | Secrets Manager/Parameter Store |
| **Logging** | stdout → CloudWatch Logs |
| **Health checks** | Add endpoints for ALB/ECS |
| **Database** | Migrate to RDS (DMS/native tools, note 06) |
| **Scaling** | Define ECS service autoscaling |
| **Security** | Scan the image (ECR scanning), run non-root, least-privilege task roles |

---

## 9. Containers Landing Choices (ECS, EKS, OpenShift/ROSA)

| | **ECS (Fargate/EC2)** | **EKS** | **OpenShift (ROSA)** |
|---|---|---|---|
| Orchestrator | AWS-native | Kubernetes | Kubernetes + platform |
| Learning curve | Low | Medium–high | Medium–high (see your Openshift notes) |
| Operations | AWS manages the control plane, and Fargate manages nodes | You manage nodes/add-ons | Red Hat SRE manages the platform |
| Build tooling | CodeBuild/ECR | Any | **S2I/BuildConfig, Tekton** (Topics 10, 19) |
| GitOps | Possible | Argo CD/Flux | **OpenShift GitOps** (Topic 20) |
| Security defaults | IAM task roles | Add-ons needed | **SCC, restricted by default** (Topic 6) |
| Portability | AWS-only | High | High |
| Best for | Simple, AWS-centric teams | Kubernetes-skilled teams | Enterprises wanting a complete platform |

For Java apps already on an application server, the **Migration Toolkit for Applications (MTA)** (Topic 23 of your OpenShift notes) is the OpenShift-oriented equivalent of A2C's analysis step.

---

## 10. Database Refactoring

Refactoring the app often means refactoring the **data layer**:

| Step | Detail |
|---|---|
| **Replatform first** | Move to a managed DB (RDS) with the same engine |
| **Then modernize** | Aurora (heterogeneous via SCT + DMS), DynamoDB for key-value/high-scale, OpenSearch for search |
| **Database per service** | New services own their data (avoid the shared database) |
| **Sync during transition** | **DMS CDC** keeps old and new in sync until you cut over |
| **Consistency** | Use events/outbox patterns for cross-service consistency |

(See `06_AWS_SCT_and_DB_Import_Export.md`.)

---

## 11. Modernization Roadmap Example

**Legacy:** Java monolith (Tomcat + Oracle) on VMware.

```
Phase 0 (Assess)   MTA/A2C analysis, SCT assessment, dependency map, tests/observability gaps
Phase 1 (Rehost)   MGN → EC2 (exit the data center on time)           ✔ business unblocked
Phase 2 (Containers) A2C → ECS/EKS (or ROSA)                          ✔ faster deploys, density
Phase 3 (Data)     Oracle → Aurora PostgreSQL (SCT + DMS)             ✔ license savings
Phase 4 (Strangle) Extract "catalog" and "notifications" as services  ✔ independent scaling
                   Event-driven via SQS/SNS/EventBridge
Phase 5 (Optimize) Autoscaling, Savings Plans, remove the monolith's remaining parts
```

Each phase is **independently valuable** and can stop at any point.

---

## 12. Assignment 6: App2Container (Optional, Step by Step)

**Goal (from your curriculum):** Launch a **Windows** machine in AWS, install a sample **.NET** application, run **App2Container** commands to containerize it, and deploy to a container service.

> This assignment may be affected by tool availability. If A2C isn't available to you, do the **alternative lab** below.

### Option A: App2Container (if available)

```
1. Launch a Windows Server 2019/2022 EC2 (t3.large), with an IAM role allowing S3, ECR, ECS/EKS, CloudFormation
2. Enable IIS (Server Manager → Add roles → Web Server) and install .NET Framework 4.8 / the sample ASP.NET app in IIS (Default Web Site)
3. Download and install App2Container (see the AWS docs for the installer for Windows)
4. In PowerShell (as Administrator):
     app2container init
     app2container inventory
     app2container analyze --application-id <iis-id>
     app2container containerize --application-id <iis-id>
     app2container generate app-deployment --application-id <iis-id>
5. Check ECR for the pushed image, deploy to ECS (Windows containers need Windows ECS hosts/EC2 launch type)
6. Browse the ALB URL and confirm the app works
7. Clean up: ECS service/cluster, ALB, ECR images, EC2, CloudFormation stacks, S3 bucket
```

### Option B: Alternative lab (works anywhere): containerize a Node.js app yourself

You already have a Node.js sample app (`Openshift/sample-app`), so containerize it **two ways**:

```
1. With a Dockerfile (docker build) → push to ECR → run on ECS Fargate behind an ALB
2. With S2I on OpenShift (your Topic 10 BuildConfig) → compare effort
3. Write down: what A2C would automate vs what you did by hand (analysis, Dockerfile, deployment templates)
```

### Record
Which steps took the longest, which app assumptions (state, config, secrets) had to change, and the rollback plan.

---

## 13. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `analyze` finds nothing | The app isn't a supported type/platform | Check the supported list, or write a Dockerfile manually |
| Container starts, app fails | Missing config/files/ports | Review `analysis.json`, and compare with the server's real environment |
| Windows container image huge/slow | Windows base images are large | Plan storage/pull time, use ECR in the same region |
| Sessions lost across containers | In-memory sessions | External session store (ElastiCache/DB) or sticky sessions (temporary) |
| App can't reach the DB | New network/security groups | Add the SG rules, and use the proper endpoints and secrets |
| ECS tasks fail health checks | No health endpoint or the wrong path | Add `/health` and configure the target group |
| File writes fail | Read-only/ephemeral filesystem | Use volumes (EFS/EBS) or object storage |
| Strangler routes loop/404 | Overlapping route paths | Specific paths first, default route last, and test each |

---

## 14. Key Takeaways

```
1. Refactor = redesign for the cloud. Highest effort, highest benefit. Do it selectively (rehost first).
2. Targets: containers (ECS/EKS/ROSA), serverless, managed services, SaaS.
3. Strangler fig = put a routing layer in front, replace one capability at a time, retire the monolith last.
4. Refactor Spaces automates the routing layer. If unavailable, use API Gateway/ALB/Route 53 weights or OpenShift Routes.
5. App2Container containerizes existing Java/.NET apps without code changes, but state, secrets, logging and scaling are still your job.
6. Refactoring the database (SCT + DMS, database per service) is part of the journey.
7. Plan modernization in phases that each deliver value, and verify the current availability of AWS tooling.
```

**Next note:** `09_Data_Transfer_Services.md`
