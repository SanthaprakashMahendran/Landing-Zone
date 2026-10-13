# AWS Elastic Disaster Recovery (DRS)

DR Concepts · How DRS Works · Drills · Recovery · Failback · Cross-Region Lab (Assignment 3)

---

## Table of Contents
1. Disaster Recovery Basics (RPO, RTO)
2. DR Strategies (The Four Patterns)
3. What is AWS Elastic Disaster Recovery?
4. DRS vs MGN (Same Technology, Different Goal)
5. Architecture
6. Credentials & Network
7. Setup: Initialize & Replication Settings
8. Installing the Agent
9. Replication & Server States
10. Launch Settings (Recovery Instance Template)
11. Drills (Non-Disruptive Testing)
12. Recovery (A Real Disaster)
13. Point-in-Time Recovery
14. Failback (Returning to the Source)
15. Networking During DR
16. Cost
17. Assignment 3: Region-to-Region DR (Step by Step)
18. Troubleshooting
19. Best Practices
20. Key Takeaways

---

## 1. Disaster Recovery Basics (RPO, RTO)

**Disaster recovery (DR)** = how you get back to working after a major failure (data center outage, region outage, ransomware, human error).

| Term | Meaning | Question |
|---|---|---|
| **RPO** (Recovery Point Objective) | Maximum **data loss** you accept | "How much recent data can we lose?" (seconds, minutes, hours) |
| **RTO** (Recovery Time Objective) | Maximum **downtime** you accept | "How fast must we be back?" (minutes, hours) |

```
              disaster
                 │
 ◀──── RPO ─────▶│◀────────── RTO ──────────▶
 last good data  │                          service restored
```

**Lower RPO/RTO = higher cost.** Every application should have an agreed RPO/RTO (it's in the discovery questionnaire in note 02).

---

## 2. DR Strategies (The Four Patterns)

| Strategy | What runs in the DR site | RPO | RTO | Cost |
|---|---|---|---|---|
| **Backup & Restore** | Nothing (just backups) | Hours | Hours to a day+ | $ lowest |
| **Pilot Light** | Core data replicated, with servers **off** (turned on during a disaster) | Seconds to minutes | Tens of minutes to hours | $$ |
| **Warm Standby** | A **scaled-down** full copy running | Seconds | Minutes | $$$ |
| **Multi-site Active/Active** | Full production in **both** sites | Near zero | Near zero | $$$$ highest |

```
Backup/Restore:  backups ───────────────────────────────▶ rebuild everything (slow)
Pilot light:     data replicated │ servers OFF ─▶ start servers during disaster
Warm standby:    small version RUNNING ─▶ scale up
Active/Active:   two full sites serving users all the time
```

**DRS implements Pilot Light** (very efficient, low cost, quick recovery).

---

## 3. What is AWS Elastic Disaster Recovery?

A service that **continuously replicates** servers (physical, virtual, or cloud) to a **low-cost staging area in AWS**, and when needed **launches full-size recovery instances in minutes**.

| Feature | Detail |
|---|---|
| **Replication** | Continuous, block-level, so RPO is typically **seconds** |
| **Recovery** | Launch instances in **minutes** (typical RTO of minutes) |
| **Source** | On-prem (physical or VMware/Hyper-V), another cloud, or **AWS EC2 in another region/AZ** |
| **Target** | An AWS region/VPC of your choice |
| **Cost** | Staging uses a small replication server plus cheap EBS, and you pay for full-size servers **only during drills/recovery** |
| **Testing** | **Drills** without affecting the source or replication |
| **Point-in-time recovery** | Recover to an earlier snapshot (for example before ransomware) |
| **Failback** | Replicate changes back to the original site after the disaster is over |
| **Successor of** | **CloudEndure Disaster Recovery** (see note 07) |

---

## 4. DRS vs MGN (Same Technology, Different Goal)

| | **MGN** | **DRS** |
|---|---|---|
| Purpose | **Migrate** (one-time move) | **Protect** (ongoing standby) |
| Replication | Continuous until cutover | Continuous **indefinitely** |
| End state | Source retired | Source stays in production |
| Launch | Test and cutover | **Drill** and **Recovery** |
| Replication end | Finalize cutover (staging deleted) | Stays on until you remove the server |
| Point-in-time snapshots | Basic | **Retention (for example days) + PIT recovery** |
| Failback | No | **Yes** |
| Agent | `aws-replication-installer-init` | The same installer family (IAM policy differs) |
| Console | Application Migration Service | Elastic Disaster Recovery |

```
Same engine: agent → 443/1500 → replication server → staging EBS → snapshots → launch EC2
Different story: MGN = "move once".  DRS = "stay protected, launch only if needed".
```

---

## 5. Architecture

```
SOURCE (on-prem / region A)                   AWS DR REGION (region B)
┌──────────────────────┐                 ┌───────────────────────────────────────────┐
│ Production server    │                 │  DRS service (control plane)               │
│ + DRS Agent          │── ① 443 ──────▶│  Source servers, replication settings,     │
│   (block-level)      │                 │  launch settings                           │
│                      │                 └────────────┬──────────────────────────────┘
│                      │                              │ manages
│                      │── ② 1500 ─────▶ ┌────────────▼────────────┐
│                      │   (data, TLS)   │ STAGING AREA SUBNET      │
└──────────────────────┘                 │  Replication Server (EC2)│
                                         │  Staging EBS volumes     │ ◀ cheap, always on
                                         │  EBS snapshots (PIT)     │ ◀ retention e.g. 7 days
                                         └────────────┬─────────────┘
                                                      │ Drill / Recovery
                                         ┌────────────▼─────────────┐
                                         │ Conversion server → RECOVERY INSTANCE (EC2)
                                         │ in your DR VPC           │ ◀ billed only while it exists
                                         └──────────────────────────┘
```

---

## 6. Credentials & Network

Same pattern as MGN (see `04_AWS_MGN_Deep_Dive.md`, sections 3 and 4):

| Item | DRS |
|---|---|
| Install-time credentials | **IAM user** access key with **`AWSElasticDisasterRecoveryAgentInstallationPolicy`** (not an EC2 role for on-prem) |
| Source → service | TCP **443** to `drs.<region>.amazonaws.com` and S3 |
| Source → replication server | TCP **1500** (TLS) |
| Replication server → AWS APIs | TCP 443 |
| Private path | VPN/Direct Connect with **private IP** for data replication |

> Verify the exact policy name and endpoints in the **DRS user guide** for your region.

---

## 7. Setup: Initialize & Replication Settings

```
Console → Elastic Disaster Recovery → Set up default replication settings
```

| Setting | Meaning | Guidance |
|---|---|---|
| **Staging area subnet** | Where replication servers live | A private subnet in the DR VPC |
| **Replication server instance type** | Default t3.small | Bigger for busy servers |
| **EBS volume type (staging)** | Auto or cheaper types | Optimize cost |
| **Use private IP for data replication** | Via VPN/Direct Connect | Yes in production |
| **Security group** | Default creates one allowing 1500 | Restrict the source CIDR |
| **Bandwidth throttling** | Limit Mbps | Protect production |
| **Point-in-time retention** | How many days of snapshots to keep (for example 7) | Longer = more cost, better ransomware protection |
| **Encryption** | EBS default or KMS | KMS for compliance |
| **Tags** | Staging resource tags | Yes |

---

## 8. Installing the Agent

Same method as MGN (outline):

```bash
# download from the DR region's regional DRS bucket (see the docs for the exact URL)
chmod +x aws-replication-installer-init
sudo ./aws-replication-installer-init --region <dr-region> \
     --aws-access-key-id <AKIA...> --aws-secret-access-key <secret>
```

- The **region you give is the DR (target) region**, where the staging area will be.
- Windows uses the same family of installer as MGN.
- After install, **delete/deactivate** the access key.
- Check the DRS docs for the current **supported OS list** and prerequisites.

---

## 9. Replication & Server States

### Data replication status

| Status | Meaning |
|---|---|
| **Initial sync** | The first full copy |
| **Backlog** | Changes waiting to send |
| **Rescanning** | Catching up |
| **Healthy** | ✅ Continuous replication, lag in seconds |
| **Stalled / Disconnected** | Problem, so check ports and the agent |

### Recovery readiness (lifecycle)

| State | Meaning |
|---|---|
| **Not ready** | Initial sync not finished |
| **Ready for recovery** | You can run drills or a recovery |
| **Recovery in progress** | Recovery instance launching/launched |
| **Recovered** | A recovery instance exists |
| **Disconnected** | Agent disconnected, so replication lost |

**Healthy + Ready for recovery** is your insurance policy. Monitor it with **alerts** (CloudWatch/EventBridge on lag and stalled status).

---

## 10. Launch Settings (Recovery Instance Template)

Configure per server, **before** you need it:

| Setting | Guidance |
|---|---|
| **Instance type** | Right-size to production needs (or use right-sizing) |
| **Subnet/VPC** | The **DR VPC subnet** (pre-built, with routes, NAT, security groups) |
| **Security groups** | Same rules as production |
| **IAM instance profile** | SSM and monitoring role |
| **Copy private IP** | Keep the source IP if the DR network allows |
| **Start instance upon launch** | Yes |
| **OS licensing** | BYOL vs License Included |
| **Post-launch actions** | SSM actions (agents, scripts, domain join) |
| **Tags** | `Environment=DR` etc. |

A **launch template** lives in EC2 for each server. **Test it in a drill.** Wrong subnets or security groups are the number one reason real recoveries are slow.

---

## 11. Drills (Non-Disruptive Testing)

A **drill** launches **recovery instances from a snapshot** while **replication continues** and **production keeps running**.

```
1. Console → Source servers → select → Initiate recovery job → "Initiate drill"
2. Choose the snapshot ("Use most recent data" or a point in time)
3. DRS launches conversion + recovery instance (minutes)
4. Validate the app (network, DNS, data, dependencies, performance)
5. Terminate drill instances ("Terminate recovery instances")
   → you stop paying for them; replication was never interrupted
```

| Rule | Why |
|---|---|
| Run drills **regularly** (for example quarterly) | Untested DR is a hope, not a plan |
| Test with **real dependencies** (DB, DNS, AD) | Single servers recover fine, systems fail on dependencies |
| Time it | Gives you a **measured RTO** |
| Use an **isolated test network** if apps would conflict with production | Avoid duplicate IPs/DNS |

---

## 12. Recovery (A Real Disaster)

Same mechanism as a drill, but you intend to **run production** there:

```
1. Declare the disaster (decision by the business owner)
2. Initiate recovery job → choose latest data (or a PIT snapshot)
3. Wait for recovery instances (minutes)
4. Validate quickly
5. Switch traffic: Route 53 failover, change load balancer/DNS, VPN routes
6. Run in DR; keep monitoring, backups and security in place
```

### Runbook (write it in advance)

| Step | Owner | Time |
|---|---|---|
| Declare disaster | Incident commander | |
| Start recovery (all tiers in order: DB → app → web) | DR lead | |
| Validate | App team | |
| DNS/traffic switch | Network | |
| Notify users | Comms | |

Order matters: **database first, then app, then web.**

---

## 13. Point-in-Time Recovery

DRS keeps **snapshots** at intervals (and over the retention period). You can launch from a **specific time**:

```
Ransomware encrypts files at 14:05.
Recovery uses the snapshot from 13:50 → clean data.
```

| Concept | Detail |
|---|---|
| Granularity | Snapshots every few minutes initially, then thinned out over the retention window |
| Retention | Configured in replication settings (days) |
| Use cases | Ransomware, corruption, accidental deletion, bad deployments |

> **Replication copies bad data too.** Continuous replication also replicates corruption or encryption, so **point-in-time** (and separate backups) is what saves you.

---

## 14. Failback (Returning to the Source)

After the disaster, you need to **return to the original site**:

```
1. Source site is repaired
2. Install the DRS Failback Client (a bootable image / agent) on the repaired source
3. DRS replicates the CHANGES made during the DR period back to the source
4. Switch back during a planned window
5. Re-initialize normal replication (source → AWS)
```

| Source type | Failback approach |
|---|---|
| On-prem physical/VMware | The **Failback Client** (boot ISO), with replication back over the network |
| AWS → AWS (region A → region B) | **Reverse replication** from the recovery instances back to the original region |

Failback is **planned and slower** than recovery, but you move only the **changed data**. Practice it in a test environment.

---

## 15. Networking During DR

| Topic | Guidance |
|---|---|
| **DR VPC** | Pre-build it (subnets, routes, NAT, security groups, endpoints), because building it during a disaster is too late |
| **IP addressing** | Same CIDR as production (easy failover, but can't connect both at once) or different CIDRs (flexible, but IPs change) |
| **DNS** | **Route 53 health checks + failover routing**, or a manual change with a **low TTL** |
| **Connectivity to users/partners** | VPN/Direct Connect to the DR region, partner IP allow lists |
| **Dependencies** | Active Directory, DNS, DB, licensing servers must be reachable in DR |
| **Load balancers** | Pre-create ALB/NLB, and register recovered instances (post-launch action or script) |

---

## 16. Cost

| Component | Billed |
|---|---|
| **DRS per source server** | Hourly rate per replicating server (check current pricing) |
| **Replication server (EC2)** | Small instance, running continuously |
| **Staging EBS volumes** | Per GB-month |
| **EBS snapshots** | Per GB-month (retention) |
| **Data transfer** | Inbound from the source is usually free, and cross-region transfer applies for AWS→AWS |
| **Recovery/drill instances** | EC2 **only while they run** |

```
Rough comparison (illustrative):
Warm standby (full servers running 24x7):          100% of production cost
Elastic DR (pilot light, small staging only):      ~10–20% of production cost  (plus short drill costs)
```

> Always check the current **AWS pricing page** for DRS.

---

## 17. Assignment 3: Region-to-Region DR (Step by Step)

**Goal:** Protect an EC2 instance in **region A** by replicating it to **region B** with DRS, run a **drill**, and clean up.

**Example:** Source = `us-east-1`, DR = `us-west-2`. Use your sandbox account.

### Part A: Prepare the DR region

```
1. VPC "DR-VPC" 10.30.0.0/16 in us-west-2
   ├─ staging-subnet 10.30.1.0/24  (public for the lab, so the source can reach port 1500)
   └─ recovery-subnet 10.30.2.0/24 (security group allows 80/22 from your IP)
2. IGW + routes
3. DRS → Initialize / set default replication settings:
   Staging subnet: staging-subnet | type: t3.small | PIT retention: 1–3 days | Public IP: ON (lab)
4. IAM user "drs-agent-install" + policy AWSElasticDisasterRecoveryAgentInstallationPolicy → access key
```

### Part B: Create the source

```
us-east-1: EC2 (Amazon Linux 2023, t3.small, 20 GB), install nginx with a page "PRODUCTION us-east-1"
Create /home/ec2-user/critical.txt with the current date
```

### Part C: Install the agent

```
SSH to the source → download the DRS installer for us-west-2 → run with --region us-west-2 and the IAM user keys
```

### Part D: Wait for protection

```
DRS console (us-west-2) → Source servers
Data replication: Initial sync → Healthy
Recovery readiness: Ready for recovery
(Observe: replication server EC2 + staging EBS in us-west-2)
```

### Part E: Configure launch settings

```
Launch settings → instance type t3.small, subnet recovery-subnet, SG (80, 22), Start on launch: Yes
```

### Part F: Run a drill

```
1. Source server → Initiate recovery job → Initiate drill → latest data
2. Wait for "Recovery in progress" → "Recovered" (a few minutes)
3. Find the new EC2 instance in us-west-2, browse http://<ip>  → "PRODUCTION us-east-1" ✅
4. Verify critical.txt
5. Note the time from "Initiate drill" to a working page = measured RTO
6. Terminate recovery instances
```

### Part G: Prove point-in-time

```
1. On the source: echo "BAD" > critical.txt (simulate corruption); wait a few minutes
2. Initiate another drill from an EARLIER snapshot → critical.txt has the old, good contents ✅
3. Terminate the instances
```

### Part H: (Optional) Simulate a real recovery

```
Stop the source instance, run "Initiate recovery job" (not a drill), validate, then discuss failback steps.
```

### Part I: Clean up (important)

```
1. Terminate recovery instances
2. DRS → Source servers → Actions → "Disconnect from AWS" / "Delete source server"
3. Delete leftover EBS volumes, snapshots, replication servers in us-west-2
4. Terminate the source EC2
5. Delete the IAM user key and the VPC resources
```

### Record
Initial sync time, healthy lag, **drill time (RTO)**, **PIT result (RPO behavior)**, and issues.

---

## 18. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Installer access denied | Wrong policy/region/key | Use `AWSElasticDisasterRecoveryAgentInstallationPolicy` and the DR region |
| Stuck in **Initial sync/Stalled** | Port 1500 blocked or no route | Check SG, NACL, routes, public/private setting |
| **Lag grows** | Low bandwidth or an undersized replication server | Increase the replication server type, check the network |
| Drill instance not reachable | Wrong subnet/SG in launch settings | Fix the template and redo the drill |
| Drill app fails | Missing dependencies (DB, AD, DNS) | Replicate dependencies and test the whole app tier |
| Duplicate IP conflicts | Same IP as production visible in the DR network | Use an isolated test subnet for drills |
| "Disconnected" | Agent stopped or the server rebooted without the agent | Restart the agent, reinstall if needed |
| Cost higher than expected | Forgotten drill instances, long PIT retention, big EBS | Terminate after drills, tune retention |
| Failback fails | Failback Client network/permissions | Verify connectivity and the DRS failback docs |

---

## 19. Best Practices

- ✅ Define **RPO/RTO per application** first, and pick the strategy to match
- ✅ **Run drills regularly** and document the measured RTO
- ✅ **Pre-build the DR network** and test launch settings
- ✅ Monitor **replication health and lag** with alerts
- ✅ Keep **separate backups** (AWS Backup, immutable). Replication isn't a backup
- ✅ Use **point-in-time retention** for ransomware scenarios
- ✅ Write and rehearse a **runbook** with order (DB → app → web)
- ✅ Replicate **dependencies** (AD, DNS, DB, file servers) together
- ✅ **Tag** and track DRS cost
- ❌ Don't skip failback planning
- ❌ Don't assume a successful replication means a successful recovery. Drill it

---

## 20. Key Takeaways

```
1. RPO = data you can lose. RTO = downtime you can tolerate.
2. Strategies: Backup/Restore → Pilot Light → Warm Standby → Active/Active (cost and speed rise together).
3. DRS = pilot light: continuous block-level replication to a cheap staging area, launch full servers only when needed.
4. Same engine as MGN (agent → 443/1500 → replication server → staging EBS), but the goal is protection, not a one-time move.
5. Drills test recovery without touching production or replication. Do them regularly.
6. Point-in-time recovery protects against ransomware/corruption (replication alone copies the damage).
7. Failback returns you to the source after the disaster, replicating only the changes.
8. Pre-build the DR VPC, launch settings and a runbook. Real recoveries fail on networking and dependencies.
```

**Next note:** `06_AWS_SCT_and_DB_Import_Export.md`
