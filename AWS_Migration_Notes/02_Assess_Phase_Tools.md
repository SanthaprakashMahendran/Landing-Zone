# Assess Phase: Tools & Deliverables

Migration Evaluator · Cloudamize & OLA · Migration Readiness Assessment (MRA) · Migration Portfolio Assessment (MPA) & CMDB · Application Discovery Questionnaire · Application Discovery Service (ADS)

---

## Table of Contents
1. What the Assess Phase Is For
2. How the Tools Fit Together
3. Migration Evaluator (TCO & Business Case)
4. Cloudamize & the Optimization and Licensing Assessment (OLA)
5. Migration Readiness Assessment (MRA)
6. Migration Portfolio Assessment (MPA) & the CMDB File
7. Application Discovery Questionnaire
8. AWS Application Discovery Service (ADS)
9. Putting It Together: Assess Phase Timeline
10. Sample Assess Report (What You Deliver)
11. Hands-on Ideas
12. Key Takeaways

---

## 1. What the Assess Phase Is For

Before moving anything, answer **four questions**:

```
1. WHAT do we have?            → inventory + dependencies   (discovery)
2. HOW is it used?             → CPU/memory/storage/network (utilization data)
3. WHAT will it cost on AWS?   → right-sized cost + licensing (business case)
4. ARE WE READY?               → people, process, security   (readiness)
```

Skipping this phase is the number one reason migrations run over budget.

---

## 2. How the Tools Fit Together

```
                              ┌─────────────────────────────┐
 Servers / VMs ──collect────▶ │ Discovery data              │
 (VMware, physical)           │  • Migration Evaluator      │
                              │  • Cloudamize               │
                              │  • ADS (agent / agentless)  │
                              └──────────────┬──────────────┘
                                             ▼
                                   CMDB file (inventory)  ◀── questionnaire answers from app owners
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
           Migration Evaluator      Migration Portfolio       Migration Readiness
           → TCO, right-sizing,     Assessment (MPA)          Assessment (MRA)
             licensing options      → 6R per app, waves       → readiness gaps
                    └────────────────────────┬────────────────────────┘
                                             ▼
                              Business case + go/no-go + migration plan
                                             ▼
                                   Mobilize phase (Migration Hub)
```

| Tool | Answers | Who runs it |
|---|---|---|
| **Migration Evaluator** | What will it cost on AWS? | AWS or partner (free to you) |
| **Cloudamize / OLA** | Right-size and licensing savings, plus dependencies | Partner-delivered (3rd-party tool) |
| **MRA** | Is the organization ready? | AWS or partner workshop |
| **MPA + CMDB** | Which strategy per app, and which waves? | AWS or partner, using **your CMDB file** |
| **Questionnaire** | What does each app owner know that tools can't see? | You, with app owners |
| **ADS** | What exists, what talks to what? | You (AWS service) |

### End-to-End Workflow (Conceptual)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. Migration Readiness Assessment (MRA)                                  │
│    Is the company ready? Identify gaps in skills, security, governance,  │
│    platform and operations.                                              │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    ▼
        ┌───────────────────────────┴───────────────────────────┐
        ▼                                                       ▼
┌─────────────────────────────────┐        ┌─────────────────────────────────┐
│ 2. Application Discovery Service│        │ 3. Migration Evaluator          │
│    Discover servers,            │        │    Estimate AWS costs and       │
│    configurations, utilization  │        │    recommend right-sizing based │
│    and dependencies.            │        │    on collected data.           │
└────────────────┬────────────────┘        └────────────────┬────────────────┘
                 └─────────────────────┬────────────────────┘
                                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 4. Migration Portfolio Assessment (MPA)                                  │
│    Analyze the application portfolio, often using CMDB and discovery     │
│    data, to prioritize applications and organize migration waves.        │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 5. AWS Application Migration Service (MGN)                               │
│    Replicate source servers, test them on AWS, and perform cutover.      │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 6. AWS Migration Hub                                                     │
│    Group applications and track migration progress across supported      │
│    migration tools.                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

> This is a **conceptual** workflow. Some activities run **in parallel** (steps 2 and 3 use the same collected data), and Migration Hub can **track progress while migration is underway**, not only at the end.

| Step | Tool | Question it answers | Phase it mostly belongs to |
|---|---|---|---|
| 1 | **MRA** | Is the company ready? | Assess |
| 2 | **ADS** | What exists, and what depends on what? | Assess |
| 3 | **Migration Evaluator** | What will it cost on AWS, and what size? | Assess |
| 4 | **MPA** | Which apps first, and which move together? | Assess → Mobilize |
| 5 | **MGN** | Replicate, test, cut over | Migrate |
| 6 | **Migration Hub** | Where does each application stand? | Mobilize → Migrate |

### Example: Migrating a Three-Tier Application

Suppose you have a **web server**, an **application server**, and a **database server**.

```
   Users ──▶ [ Web server ] ──▶ [ Application server ] ──▶ [ Database server ]
```

| Step | What you do for this application |
|---|---|
| **1. MRA** | Confirm the company has the security, networking, skills and operational processes needed for AWS. |
| **2. Discovery Service** | Discover the three servers and identify their dependencies (web → app → DB, plus any external calls). |
| **3. Migration Evaluator** | Estimate the AWS cost using their utilization and configuration data. |
| **4. MPA** | Use application and dependency information to help decide the migration order and whether the servers should move together. |
| **5. MGN** | Replicate the **web and application servers** and test them on AWS. If the database is being migrated **as a database workload**, evaluate **AWS DMS** instead of assuming MGN is the right method. |
| **6. Migration Hub** | Track the migration status of the application components through supported integrations. |

**Why the database is a special case:** MGN copies a whole server (disks, OS, everything), so it works for a database server you want to keep as a server (**rehost**). If you want a **managed database** (for example **RDS or Aurora**, a **replatform**), you move the data with **DMS** (and **SCT** for a different engine). See `06_AWS_SCT_and_DB_Import_Export.md`.

```
Web server ──MGN──▶ EC2         ┐
App server ──MGN──▶ EC2         ├─ one wave (same application, tested together)
Database   ──DMS──▶ RDS/Aurora  ┘   (or MGN → EC2 if you keep the DB as a server)
```

---

## 3. Migration Evaluator (TCO & Business Case)

### What it is
A service (formerly **TSO Logic**) that builds a **data-driven business case**: *"here's your on-prem cost, and here's the right-sized AWS cost."* It is typically engaged through your **AWS account team or a partner**, and the assessment itself is free to you.

### How it works

```
1. Collect data     → Agentless Collector (a VM appliance in your network) reads from vCenter,
                      Hyper-V, SQL servers, etc. OR you import data you already have
                      (CSV/Excel exports, RVTools, CMDB)
2. Wait for enough data → commonly ~2–4 weeks, to capture real usage peaks
3. Analyze          → right-sizing based on actual utilization (not on how big the VM was ordered)
4. Report           → Quick Insights (fast, rough)  →  Business Case report (detailed)
```

### What data it looks at

| Data | Why |
|---|---|
| CPU, memory (average and peak, usually percentiles) | Right-size the EC2 instance |
| Storage size and IOPS | Choose EBS type and size |
| Network throughput | Check bandwidth and transfer cost |
| OS and database versions | Licensing (Windows Server, SQL Server, Oracle) |
| Server age and hardware | On-prem refresh cost avoided |
| Running state (powered on/off) | Identify unused machines |

### What the report shows

| Section | Content |
|---|---|
| **Current cost (baseline)** | Hardware, software, power, space, staff, licensing |
| **AWS cost options** | On-Demand vs Savings Plans/Reserved Instances |
| **Licensing models** | **BYOL vs License Included** for Windows/SQL Server |
| **Right-sizing recommendation** | Per server: instance type and EBS |
| **Savings** | % and total over 3–5 years |
| **Excluded/idle servers** | Candidates to retire |

### Example

```
On-prem annual cost (40 servers):        $380,000
Proposed AWS (right-sized, 3yr SP):      $245,000
Estimated annual saving:                 $135,000  (35%)
  of which right-sizing:                 $70,000
  of which licensing optimization:       $35,000
  of which retired servers (6):          $30,000
```

### Tips
- **Collect at least a full business cycle** (for example include month-end), or peaks are missed.
- Right-sizing from **utilization**, not from provisioned size, is where most savings come from.
- A Quick Insights report is a start, but the **Business Case** is what leadership approves.

---

## 4. Cloudamize & the Optimization and Licensing Assessment (OLA)

### Cloudamize
A **third-party discovery and assessment platform**, used by AWS partners, that:
- Collects **performance data** and **dependencies** (agent-based or agentless)
- Recommends **right-sized AWS instances**
- Estimates **cost** and **migration complexity**
- Groups servers into **application dependency maps**

### OLA: Optimization and Licensing Assessment
An AWS-offered assessment (often partner-delivered using tools like Cloudamize) focused on **cost and licensing**:

```
OLA looks at:
├─ Over-provisioned servers             → smaller instances
├─ Windows Server / SQL Server licenses → License Included vs BYOL vs downgrade editions
├─ Unused / idle resources              → retire
├─ Storage tiers                        → right storage class
└─ Pricing models                       → Savings Plans, RIs, Spot
```

| | **Migration Evaluator** | **Cloudamize / OLA** |
|---|---|---|
| Owner | AWS | Partner tool |
| Strength | Business case, TCO, licensing | Detailed performance + dependency mapping |
| Typical use | Executive business case | Detailed migration planning and right-sizing |
| Used together? | ✅ often, data from one feeds the other | |

> You usually don't buy these directly. A partner or AWS account team runs them. **Learn what the outputs mean and which questions to ask.**

---

## 5. Migration Readiness Assessment (MRA)

### What it is
A **structured questionnaire/workshop** that measures how ready your **organization** is, across the **six perspectives** of the **AWS Cloud Adoption Framework (CAF)**:

| Perspective | Example questions |
|---|---|
| **Business** | Is there an executive sponsor? A funded business case? |
| **People** | Are there AWS-skilled people? A training plan? |
| **Governance** | Cost management, tagging, portfolio ownership? |
| **Platform** | Landing zone? Network design? Workload architecture knowledge? |
| **Security** | Identity, data protection, compliance requirements, logging? |
| **Operations** | Monitoring, backup, incident response, patching in the cloud? |

### Output

```
Readiness heat map (illustrative):

Business     ██████████░░  Strong
People       ████░░░░░░░░  Gap  → training plan
Governance   ██████░░░░░░  Medium
Platform     ████░░░░░░░░  Gap  → build landing zone
Security     ███████░░░░░  Medium → define data classification
Operations   ███░░░░░░░░░  Gap  → design cloud ops/runbooks
```

The result is a **prioritized remediation list**, which becomes the core of the **Mobilize** phase.

### Why it matters
Technical migration tools won't fix a missing **operating model**. A common failure is "we moved everything, and nobody knows how to run it."

---

## 6. Migration Portfolio Assessment (MPA) & the CMDB File

### CMDB (Configuration Management Database)
The **inventory** of your servers and applications. If you have none, you build a spreadsheet. MPA takes that file as input.

### Typical CMDB columns

| Column | Example |
|---|---|
| Server name | web-prod-01 |
| IP address | 192.168.1.100 |
| Environment | Prod / Dev / Test |
| Application name | Customer Portal |
| Application owner | A. Rao |
| Business criticality | Tier 1 / 2 / 3 |
| OS and version | Windows Server 2016 |
| CPU cores / RAM (GB) | 8 / 16 |
| Storage (GB) | 500 |
| Avg / peak CPU % | 15 / 60 |
| Avg / peak memory % | 40 / 75 |
| Database type/version | SQL Server 2016 |
| Dependencies | DB: sql-prod-02, API: partner.example.com |
| Licensing | Windows (SA), SQL Std |
| Compliance | PCI |
| Hypervisor / physical | VMware 7 |
| End-of-support date | 2026-01-14 |
| Downtime window | Sat 02:00–06:00 |

### What MPA produces

```
Input: CMDB file
   ▼
MPA (AWS / partner tool)
   ├─ Suggested strategy per app (6R)
   ├─ Migration complexity score
   ├─ TCO comparison
   ├─ Suggested wave groupings
   └─ Right-sizing hints
```

### Tips
- **Data quality decides output quality.** Missing owners, wrong OS versions and "unknown" dependencies produce weak plans.
- Clean duplicates, flag **powered-off** servers, and mark **end-of-support** OS versions (they influence the strategy).

---

## 7. Application Discovery Questionnaire

Tools can't tell you **why** an app exists, who depends on it, or when you can take it down. App owners can.

### Ask the application owner

**Business**
- What does the app do? Who uses it, and how many users?
- How critical is it (Tier 1/2/3)? What's the cost of one hour of downtime?
- Planned changes (retirement, replacement, major upgrade)?

**Technical**
- Languages, frameworks, versions, OS, middleware?
- Databases and sizes? Growth rate?
- Is it **stateless**? Where does it store files?
- Hard-coded IPs, hostnames, license-by-MAC addresses?
- Authentication method (AD, local, SSO)?

**Dependencies**
- Which systems call this app? Which systems does it call (internal and external)?
- Batch jobs, file shares, schedulers, mail relays?

**Data and compliance**
- Data classification (public/internal/confidential/PCI/PII)?
- Data residency or audit requirements?

**Operations**
- **RTO/RPO** (how long can it be down, how much data can you lose)?
- Maintenance windows, blackout dates (for example year-end)?
- Backups, monitoring, DR in place?
- Support team and vendor contracts?

**Licensing**
- Per-core, per-socket, per-user? Tied to hardware? Moves to the cloud?

### How you use the answers
They fill the **CMDB** columns that tools can't detect, and they decide the **strategy** (6Rs) and the **wave** for each app.

---

## 8. AWS Application Discovery Service (ADS)

### What it is
An AWS service that **automatically discovers servers and their dependencies** and feeds **Migration Hub**.

### Two ways to collect

| | **Agentless Collector** (VMware / Hyper-V) | **Discovery Agent** (per server) |
|---|---|---|
| Install | One virtual appliance (OVA) in vCenter | Agent on each server (Windows or Linux) |
| Collects | VM inventory, config, **utilization** (CPU, memory, disk) | Server config, **time-series performance**, **running processes**, **network connections (dependencies)** |
| Dependencies | ❌ No | ✅ **Yes** |
| Effort | Low (one install) | Higher (many installs) |
| Best for | Quick inventory and sizing of VMware estates | Dependency mapping and physical servers |

> Many projects use **both**: agentless for broad inventory, agents on the servers where dependencies matter.

### Flow

```
Server/VM ──(collector or agent)── HTTPS (443) ──▶ ADS (in your Migration Hub home region)
                                                     │
                                  ┌──────────────────┼───────────────────┐
                                  ▼                  ▼                   ▼
                            Migration Hub     Export to CSV      Amazon Athena queries
                          (server list, groups)  (CMDB input)   (analyze network dependencies)
```

### What dependency data looks like

```
web-prod-01  ──TCP 3306──▶  db-prod-02      (MySQL)
web-prod-01  ──TCP 6379──▶  cache-prod-01   (Redis)
web-prod-01  ──TCP 443 ──▶  partner API     (external)
batch-01     ──TCP 445 ──▶  fileserver-01   (SMB)
```

→ `web-prod-01`, `db-prod-02`, `cache-prod-01` belong in **the same wave**; `fileserver-01` is a hidden dependency you'd otherwise miss.

### Setup (agent-based, outline)

```
1. Choose the Migration Hub home region
2. Create an IAM user for the agent, with the ADS agent access policy (AWSApplicationDiscoveryAgentAccess)
3. Download the agent installer, install it on each server with region + access key
4. Servers appear in ADS/Migration Hub; start data collection
5. Let it collect for 2–4 weeks (covers month-end and batch jobs)
6. Review dependencies; group servers into applications
7. Export data → CMDB / MPA
```

> Service and agent details change. Check the **ADS user guide** for current installers and policies.

---

## 9. Putting It Together: Assess Phase Timeline

```
Week 1   Kick-off, sponsor, scope, stakeholders
         Install discovery tools (ADS collector/agents, Migration Evaluator collector)
Week 1–4 Data collection runs (utilization + dependencies)
Week 2   Questionnaires sent to app owners
Week 2   MRA workshop (readiness)
Week 3   Build CMDB from tool exports + questionnaires, clean the data
Week 4   MPA run → strategy and wave suggestions
Week 4   Migration Evaluator Business Case
Week 5   Review, decide go/no-go, hand over to Mobilize
```

---

## 10. Sample Assess Report (What You Deliver)

```
=== ASSESSMENT SUMMARY ===
Scope:       40 servers, 18 applications, 3 databases, 2 sites
Data period: 30 days (including month-end)

1. Inventory
   40 servers (28 VMware VMs, 12 physical)   → 34 in use, 6 idle (retire candidates)
   OS: 22 Windows (6 end-of-support), 18 Linux

2. Strategy recommendation (MPA)
   Rehost 22 │ Replatform 8 │ Retire 6 │ Repurchase 2 │ Retain 1 │ Refactor 1

3. Cost (Migration Evaluator)
   On-prem (annual):     $380k
   AWS (3yr Savings Plan, right-sized): $245k      → saving $135k/yr (35%)

4. Readiness (MRA)
   Gaps: People (AWS skills), Platform (no landing zone), Operations (no cloud runbooks)

5. Risks
   • Hidden dependency: file server used by 5 apps (found by ADS)
   • Windows 2008 servers (6) need OS upgrade or replatform
   • PCI app requires private network design

6. Recommended next steps
   Build landing zone → train team → pilot (intranet wiki) → Wave 1 dev/test
```

---

## 11. Hands-on Ideas

| Exercise | What you learn |
|---|---|
| Build a **CMDB spreadsheet** for your own lab servers with the columns in section 6 | Data quality |
| Fill out the **questionnaire** for the app in `OnPrem_to_AWS_Migration_Guide.md` | Business and dependency questions |
| Create an ADS **Discovery Agent** IAM user and install the agent on a test VM or EC2 *(sandbox)* | Real discovery data |
| Query exported ADS data in **Athena** *(sandbox)* | Dependency analysis |
| Do a **mini TCO**: current server cost vs `m5.large` On-Demand and a 1-year Savings Plan | Business case basics |
| Score yourself on the **six CAF perspectives** (0–5) | Readiness |

---

## 12. Key Takeaways

```
1. Assess answers: What do we have? How is it used? What will it cost? Are we ready?
2. Migration Evaluator → TCO/business case (collect real utilization, 2–4 weeks).
3. Cloudamize/OLA → right-sizing + licensing savings + dependency maps (partner-delivered).
4. MRA → organizational readiness across six CAF perspectives. It feeds the Mobilize phase.
5. MPA + CMDB → strategy (6R) and waves per application. Garbage in, garbage out.
6. Questionnaires capture what tools can't (criticality, RTO/RPO, owners, compliance).
7. ADS → discovery; agent-based gets dependencies, agentless is quick inventory.
8. Always collect over a full business cycle and clean the data before planning waves.
```

**Next note:** `03_Mobilize_Migration_Hub_Landing_Zone.md`
