# AWS Migration Acceleration Program (MAP) & the 6 Rs

---

## Table of Contents
1. What is MAP?
2. The Three Phases (Assess → Mobilize → Migrate & Modernize)
3. What Happens in Each Phase
4. The 6 Rs (and the 7th)
5. Choosing a Strategy (Decision Guide)
6. Wave Planning
7. MAP Funding & the `map-migrated` Tag
8. Real Example: A Small Company's Plan
9. Common Mistakes
10. Key Takeaways

---

## 1. What is MAP?

**MAP = Migration Acceleration Program.** It's AWS's structured approach (plus funding and partner support) for moving a large number of workloads to AWS.

```
MAP gives you:
├─ A proven METHOD      (3 phases, tools, templates)
├─ MONEY                (credits and funding that offset migration cost)
├─ PEOPLE               (AWS teams + certified partners)
└─ TRAINING             (skills for your team)
```

**Why a framework?** Migrating 200 servers is not 200 separate projects. Without a method, teams skip discovery, forget dependencies, and cut over in the wrong order.

---

## 2. The Three Phases

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐
│   1. ASSESS  │ ──▶ │ 2. MOBILIZE  │ ──▶ │ 3. MIGRATE & MODERNIZE│
│              │     │              │     │                      │
│ Are we ready?│     │ Get ready    │     │ Move the workloads   │
│ What will it │     │ (foundation, │     │ in waves, then       │
│ cost & save? │     │  skills, plan│     │ optimize             │
│              │     │  pilot)      │     │                      │
└──────────────┘     └──────────────┘     └──────────────────────┘
   weeks                1–3 months            months to years
```

| Phase | Question it answers | Main output |
|---|---|---|
| **Assess** | Should we migrate, and what will it cost and save? | Business case, readiness score, rough portfolio |
| **Mobilize** | Are we set up to migrate? | Landing zone, detailed portfolio plan, trained team, a successful pilot |
| **Migrate & Modernize** | Move it | Workloads running on AWS, then optimized |

---

## 3. What Happens in Each Phase

### Phase 1: Assess

```
├─ Discover what you have            (servers, apps, databases)
├─ Collect usage data                (CPU, memory, disk, network)
├─ Build a business case / TCO       (cost today vs on AWS)
├─ Check organizational readiness    (people, process, security)
└─ Decide: go / no-go + scope
```

Tools: Migration Evaluator, Migration Readiness Assessment (MRA), Cloudamize/OLA, Migration Portfolio Assessment (MPA) and the CMDB file, Application Discovery Service. (Details in `02_Assess_Phase_Tools.md`.)

### Phase 2: Mobilize

```
├─ Build the landing zone            (accounts, network, security, logging)
├─ Define the operating model        (who runs what after migration)
├─ Train people                      (AWS skills)
├─ Finish discovery and dependencies (which apps talk to which)
├─ Choose a strategy for each app    (the 6 Rs)
├─ Plan the waves                    (what moves first)
└─ Run a PILOT                       (migrate 1–3 low-risk apps end to end)
```

Tools: Control Tower / Landing Zone, Application Discovery Service, Migration Hub. (Details in `03_Mobilize_Migration_Hub_Landing_Zone.md`.)

### Phase 3: Migrate & Modernize

```
For each wave:
  1. Replicate / copy      (MGN, DMS, DataSync...)
  2. Test                  (launch test instances, validate)
  3. Cutover               (planned window, switch traffic)
  4. Hypercare             (watch closely for 1–2 weeks)
  5. Decommission on-prem

After the waves:
  Optimize cost (right-size, Savings Plans), modernize (containers, serverless, managed DBs)
```

---

## 4. The 6 Rs (and the 7th)

| # | Strategy | What it means | Typical AWS tools | Effort | Cloud benefit |
|---|---|---|---|---|---|
| 1 | **Rehost** ("lift & shift") | Move as-is to EC2 | **MGN** | Low | Low–medium |
| 2 | **Replatform** ("lift, tinker & shift") | Small optimizations (e.g., DB → RDS) | MGN + **DMS**, Elastic Beanstalk | Medium | Medium |
| 3 | **Repurchase** ("drop & shop") | Replace with SaaS | Vendor migration tools | Low–medium | Medium–high |
| 4 | **Refactor / Re-architect** | Redesign for cloud-native | Lambda, ECS/EKS, App2Container | High | High |
| 5 | **Retire** | Switch it off | (archive data to S3/Glacier) | Very low | Saves 100% of that app's cost |
| 6 | **Retain** | Keep on-prem for now | VPN / Direct Connect for hybrid | None | None (yet) |
| 7 | **Relocate** (the "7th R") | Move VMs to **VMware Cloud on AWS** at hypervisor level, no changes | VMware tools (HCX) | Low | Low |

### Plain-language examples

| Strategy | Example |
|---|---|
| Rehost | A Windows app server becomes an EC2 instance, unchanged |
| Replatform | Same app server on EC2, but its MySQL moves to **RDS** |
| Repurchase | On-prem Exchange → Microsoft 365; on-prem CRM → Salesforce |
| Refactor | A monolith becomes microservices on ECS/EKS (or OpenShift on ROSA, see your OpenShift notes) with Lambda functions |
| Retire | An old reporting server nobody has used for a year |
| Retain | A mainframe, or an app with a data-residency rule |
| Relocate | A whole VMware cluster moved to VMware Cloud on AWS |

> In discovery, it is common to find that **10–20% of the portfolio can be retired**. That's pure savings.

---

## 5. Choosing a Strategy (Decision Guide)

```
Is the application still needed?
├─ No ───────────────────────────────────────────────▶ RETIRE
└─ Yes
    │
    Is there a SaaS product that does the same job well?
    ├─ Yes ──────────────────────────────────────────▶ REPURCHASE
    └─ No
        │
        Must it stay on-prem (compliance, latency, mainframe, just upgraded)?
        ├─ Yes ──────────────────────────────────────▶ RETAIN (revisit later)
        └─ No
            │
            Do you need cloud benefits NOW (scale, managed services)
            and have time and budget?
            ├─ Yes, major benefits ──────────────────▶ REFACTOR
            ├─ Yes, small wins (managed DB, etc.) ───▶ REPLATFORM
            └─ No, just move it quickly ─────────────▶ REHOST
```

### Scoring each app (simple matrix)

| Factor | Pushes toward rehost | Pushes toward refactor |
|---|---|---|
| Deadline (data center exit date) | Tight | Flexible |
| App age / support status | Stable, rarely changed | Actively developed |
| Team skills | Ops-heavy | Strong developers |
| Business value of changes | Low | High (needs scale/agility) |
| Technical debt | Acceptable | Blocks new features |

**Typical result:** most portfolios end up as roughly **rehost 40–60%, replatform 10–20%, retire 10–20%, retain a few, refactor a few, repurchase some.** Don't try to refactor everything. Rehost first and modernize later is a valid path.

---

## 6. Wave Planning

A **wave** is a group of applications migrated together.

### How to group applications

```
1. Map dependencies   (App A talks to DB B and service C → they move together or via a hybrid link)
2. Rate each app      (complexity, business criticality, downtime tolerance)
3. Group into waves   (shared dependencies, same owner, similar strategy)
4. Order the waves    (easy first, hard later)
```

### Typical wave order

| Wave | Contents | Why |
|---|---|---|
| **Pilot** | 1–3 simple, low-risk apps | Prove the process and landing zone, and train the team |
| **Wave 1** | Dev/test environments | Low business risk |
| **Wave 2–N** | Production apps by complexity | Build confidence |
| **Last** | Highly complex, high-risk apps, and the retain list | Learn from earlier waves |

### Wave plan template

| Wave | Date | Apps | Servers | Strategy | Cutover window | Owner | Rollback plan |
|---|---|---|---|---|---|---|---|
| Pilot | Week 8 | Intranet wiki | 2 | Rehost | Sat 02:00–06:00 | A. Rao | Switch DNS back |
| 1 | Week 12 | Dev/test (6 apps) | 14 | Rehost | Anytime | Team leads | Keep source |
| 2 | Week 16 | HR portal + DB | 5 | Replatform | Sun 01:00–05:00 | B. Khan | Keep source 7 days |

### Hybrid period
While waves run, on-prem and AWS must talk to each other. That's why **Site-to-Site VPN or Direct Connect** (see `VPN_Setup_and_MGN_Migration.md`) comes first.

---

## 7. MAP Funding & the `map-migrated` Tag

MAP (when you're enrolled through AWS or a partner) offers **credits and funding** that offset migration cost.

| Idea | Detail |
|---|---|
| **Eligibility** | A signed MAP agreement, with a minimum commitment (set by AWS). Ask your AWS account team or partner |
| **What it covers** | Typically part of the AWS spend for migrated workloads for a period, plus assessment/mobilize support |
| **Tracking** | Migrated resources are tagged **`map-migrated`** (value assigned in your MAP agreement) so AWS can measure eligible spend |

**Practical rule:** if you're in MAP, **tag every migrated resource** (MGN can apply tags through launch settings and Terraform can apply tags via `default_tags`). Untagged resources may not count.

> Programs and funding rules change. Confirm the current terms with AWS or your partner.

---

## 8. Real Example: A Small Company's Plan

**Company:** 40 servers, 1 data center lease ending in 12 months.

| Step | Result |
|---|---|
| **Assess (3 weeks)** | Migration Evaluator: running on AWS saves ~30% with right-sizing. 6 servers found unused |
| **Mobilize (6 weeks)** | Landing zone built, VPN up, team trained, dependency map done, waves planned, pilot: intranet wiki moved with MGN |
| **Migrate wave 1 (4 weeks)** | 14 dev/test servers (rehost) |
| **Migrate wave 2 (6 weeks)** | 12 prod apps; 3 databases moved to RDS (replatform) |
| **Migrate wave 3 (6 weeks)** | Remaining apps; 6 retired; 1 mainframe retained; CRM repurchased |
| **Optimize (ongoing)** | Right-size, Savings Plans, plan refactoring of the largest monolith |

```
Strategy mix:  Rehost 22 │ Replatform 8 │ Retire 6 │ Repurchase 2 │ Retain 1 │ Refactor 1
```

---

## 9. Common Mistakes

| Mistake | Result | Fix |
|---|---|---|
| Skipping discovery | Surprise dependencies break apps after cutover | Run ADS / discovery for at least 2–4 weeks |
| No landing zone | Insecure, inconsistent accounts | Build Control Tower first |
| Trying to refactor everything | Project stalls | Rehost most, modernize the few that matter |
| Moving apps one by one without waves | Cross-site latency, mixed dependencies | Group by dependency |
| No pilot | First real migration is the first test | Always pilot |
| No rollback plan | Panic during cutover | Keep the source untouched until verified |
| Forgetting licensing | Unexpected costs | Check BYOL vs License Included early (OLA) |
| Forgetting to decommission | Paying for both environments | Plan decommission in each wave |

---

## 10. Key Takeaways

```
1. MAP = method + funding + partners, in 3 phases: Assess, Mobilize, Migrate & Modernize.
2. 6 Rs: Rehost, Replatform, Repurchase, Refactor, Retire, Retain (+ Relocate as the 7th).
3. Decide per application, not per company. Most portfolios use a mix.
4. Retire first (free savings), rehost most, refactor the few that need it.
5. Group applications into waves by dependency, and always run a pilot.
6. Tag migrated resources (map-migrated) if you're using MAP funding.
7. Hybrid connectivity (VPN / Direct Connect) is needed while waves run.
```

**Next note:** `02_Assess_Phase_Tools.md`
