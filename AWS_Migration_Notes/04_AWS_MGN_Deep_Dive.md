# AWS Application Migration Service (MGN): Deep Dive

Architecture · Credentials · Replication · Settings · Lifecycle · Testing · Cutover · Cross-Region Lab (Assignment 2)

> This note **extends and corrects** `VPN_Setup_and_MGN_Migration.md`. That note has good step-by-step material for the VPN. Use this note for how MGN actually works. See section 16 for the corrections.

---

## Table of Contents
1. What MGN Does
2. Architecture (Who Talks to Whom)
3. Credentials: How the Agent Is Allowed In
4. Network Requirements (Ports and Paths)
5. Initializing MGN & Replication Settings Template
6. Installing the Agent
7. Replication States (What the Console Shows)
8. Launch Settings (How the Target EC2 Will Look)
9. Source Server Lifecycle
10. Test → Cutover → Finalize
11. Post-Launch Actions
12. Applications & Waves in MGN
13. Agentless Option (vCenter)
14. Assignment 2: Cross-Region Migration (Step by Step)
15. Troubleshooting
16. Corrections to the Existing MGN Notes
17. Key Takeaways

---

## 1. What MGN Does

MGN is AWS's **rehost (lift & shift)** service. It does **continuous, block-level replication** of a source server's disks to AWS, so you can launch an EC2 copy with **minimal downtime** (usually a few minutes at cutover).

```
Source server (physical, VMware, Hyper-V, or another cloud/region)
   │ agent copies every disk block, then every new write
   ▼
AWS staging area (low-cost, always on during replication)
   │ when you click "Launch"
   ▼
Converted EC2 instance (drivers/boot fixed automatically)
```

It supports many OS versions (Windows and Linux), and replicates **whole servers** (OS + apps + data).

---

## 2. Architecture (Who Talks to Whom)

```
SOURCE (on-prem / other region)                       TARGET AWS ACCOUNT / REGION
┌──────────────────────┐                  ┌───────────────────────────────────────────────┐
│  Source server       │                  │  MGN service (control plane)                   │
│  + Replication Agent │── ① 443 ───────▶ │  • Source Server records                       │
│  (block-level driver)│  (register,      │  • Replication Settings template               │
│                      │   control,       │  • Launch Settings per server                  │
│                      │   status)        └──────────────┬─────────────────────────────────┘
│                      │                                 │ launches & manages
│                      │                  ┌──────────────▼──────────────┐
│                      │── ② 1500 ──────▶ │  STAGING AREA SUBNET         │
│                      │  (disk data,     │   Replication Server (EC2)   │ ◀─ small instance, default t3.small
│                      │   TLS)           │     │ writes                  │
└──────────────────────┘                  │   Staging EBS volumes        │ ◀─ one per source disk
                                          └──────────────┬───────────────┘
                                                         │ at Test/Cutover
                                          ┌──────────────▼───────────────┐
                                          │ EBS snapshot → Conversion     │ ◀─ temporary EC2, converts boot/drivers
                                          │ Server → LAUNCHED EC2 (final) │
                                          └──────────────────────────────┘
```

| Component | Purpose | Lifetime |
|---|---|---|
| **Replication Agent** | On the source: reads disks, sends changes | Until you finalize cutover |
| **MGN service** | Orchestrates everything | Always |
| **Staging area subnet** | Where replication resources live | Your choice of VPC/subnet |
| **Replication Server** | Receives data and writes to staging EBS | Auto-launched; one can serve **several source disks** |
| **Staging EBS volumes** | Hold the replicated copy | Until cutover is finalized |
| **EBS snapshots** | Point-in-time copies used to launch | Created at launch |
| **Conversion Server** | Prepares the instance (drivers, bootloader) | Temporary, a few minutes |
| **Launched instance** | Your migrated server (test or cutover) | Permanent |

---

## 3. Credentials: How the Agent Is Allowed In

(See also the explanation in chat; summarized here.)

An on-prem VM has **no EC2 instance profile**, so **it cannot use an EC2 IAM role**. The agent needs **IAM user access keys**, used **only at install time**.

```
AWS side (one time)                         On-prem
1. Create IAM USER  mgn-agent-install       4. Run installer with the user's keys
2. Attach policy                                    │
   AWSApplicationMigrationAgentInstallationPolicy   │ signed API call over 443
3. Create access key  ───────────────────────────────┘
                                             5. MGN checks permission → creates a Source Server record
                                             6. The agent gets its own identity and starts replicating
7. Delete / deactivate the access key afterward
```

| Role/Policy | Who | Created by |
|---|---|---|
| IAM **user** + `AWSApplicationMigrationAgentInstallationPolicy` | Used by the installer once | **You** |
| **Service-linked role** for MGN | MGN service itself | MGN, at initialization |
| **Replication Server role** and **Conversion Server role** | AWS-side EC2 instances | MGN, at initialization |

> **Don't** create an EC2 role for this. It can't be used on-prem.

---

## 4. Network Requirements (Ports and Paths)

### From the source server

| Destination | Port | Purpose |
|---|---|---|
| **MGN API endpoint** (`mgn.<region>.amazonaws.com`) | TCP **443** | Registration, control, status |
| **S3 (regional)** | TCP 443 | Agent installer/software downloads |
| **Replication Server** (staging subnet) | TCP **1500** | **Disk data** (TLS-encrypted) |

### From the Replication Server (inside AWS)

| Destination | Port | Purpose |
|---|---|---|
| MGN, S3, EC2 endpoints | TCP 443 | Control, snapshots, API calls |

### Public or private data path

| | Internet | **VPN / Direct Connect** (recommended for large or sensitive data) |
|---|---|---|
| Replication Settings | "Create public IP" **on** | Public IP **off**, "Use private IP for data replication" **on** |
| Source sends 1500 to | Replication server public IP | Replication server **private** IP via VGW/Direct Connect |
| Security group | 1500 from the internet | 1500 **from on-prem CIDR only** |
| Control (443) | Internet | Internet, or **VPC interface endpoints** through the VPN for fully private |

```
Source ──1500──▶ (VPN tunnel) ──▶ Replication Server (private IP in staging subnet)
Source ──443───▶ (internet or interface endpoint) ──▶ MGN API
```

### Sizing the pipe

```
Time ≈ data size ÷ (usable bandwidth)
100 GB over 100 Mbps  ≈ 2.5 hours   (at 100%; allow ~20–30% overhead)
1 TB   over 100 Mbps  ≈ 1 day
Initial sync is the long step. After that, only changes flow.
```

You can **throttle replication bandwidth** per server (Replication Settings) so production traffic isn't starved.

---

## 5. Initializing MGN & Replication Settings Template

### Initialize the service (once per region)

```
Console → Application Migration Service → Get started → Set up service
```

MGN creates its **service-linked roles** and **IAM roles** and opens the **Replication Settings template**.

### Replication Settings template (the defaults for all new servers)

| Setting | Meaning | Guidance |
|---|---|---|
| **Staging area subnet** | Where the replication server and staging volumes live | A dedicated, private "migration" subnet |
| **Replication server instance type** | Default **t3.small** | Increase (for example `c5.large`) for large or busy servers |
| **Dedicated instance** | Whether replication servers run on dedicated hardware | Rarely needed |
| **EBS volume type for staging** | Auto, or choose gp3/gp2/st1/sc1 | Cheaper types for cold bulk data |
| **EBS encryption** | Default EBS key or your KMS key | Use KMS if you require it |
| **Security group** | MGN can create one (allows 1500 inbound) | **Restrict source CIDR**, especially over VPN |
| **Public IP / private IP** | See section 4 | Prefer private via VPN |
| **Bandwidth throttling** | Mbps limit | Set during business hours |
| **Tags** | Applied to replication resources | Add `Project`, `map-migrated` etc. |

The **template** applies to **new** source servers. Existing servers keep their own copy, so edit per server if needed.

---

## 6. Installing the Agent

### Linux (outline)

```bash
# Download from the regional MGN bucket (check the AWS docs for the exact URL for your region)
wget -O ./aws-replication-installer-init \
  https://aws-application-migration-service-<region>.s3.<region>.amazonaws.com/latest/linux/aws-replication-installer-init
chmod +x aws-replication-installer-init

sudo ./aws-replication-installer-init \
  --region <region> \
  --aws-access-key-id <AKIA...> \
  --aws-secret-access-key <secret>
```

The installer lists the disks and asks which to replicate (or use options for non-interactive installs).

### Windows (outline)

```
Download AwsReplicationWindowsInstaller.exe from the same regional bucket,
run as Administrator, enter region + access key + secret, choose disks.
```

### Prerequisites on the source
- Supported OS version, root/Administrator access
- Free disk space (a few GB), and for Linux **kernel headers/`gcc`/`make`** for the driver build (Windows has a prebuilt driver)
- Outbound 443 and 1500, as in section 4
- Servers should have a **stable disk layout** and a **synced clock** (NTP)

> **Verify** the exact installer names, URLs and flags in the current **MGN user guide**. They change by version and region.

---

## 7. Replication States (What the Console Shows)

**Data replication status** (per server):

| Status | Meaning |
|---|---|
| **Initial sync** | First full copy of all disk blocks (hours to days) |
| **Backlog** | Changes waiting to be sent (normal during initial sync or bursts) |
| **Rescanning** | The agent re-reads disks to catch up (after a reboot/outage) |
| **Creating snapshot** | MGN takes a point-in-time snapshot |
| **Continuous data replication / Healthy** | ✅ Up to date, lag measured in seconds |
| **Stalled** | No progress, so check network and agent |
| **Paused / Disconnected** | Replication stopped or the agent unreachable |

**Replication lag** = how far the AWS copy is behind the source.

```
Healthy → good to test.  Lag growing → bandwidth too low or server too busy.
```

---

## 8. Launch Settings (How the Target EC2 Will Look)

MGN stores, per server, **Launch Settings** (shown in the console; backed by an EC2 launch template).

| Setting | Meaning | Guidance |
|---|---|---|
| **Instance type right-sizing** | MGN picks an EC2 type from the source's CPU/RAM | Turn **on**, then verify |
| **Instance type** | Manual override | Match Migration Evaluator's recommendation |
| **Start instance upon launch** | Boot right after launch | On for tests |
| **Copy private IP** | Keep the source IP if free in the subnet | Useful, but IPs must not conflict |
| **Transfer server tags** | Copy source tags | Yes |
| **Subnet / Security groups** | Via the EC2 launch template | Use the **target app subnet** and proper SGs (not the staging area!) |
| **OS licensing** | **BYOL** vs **License Included** (Windows, SQL) | Decide with finance, since this changes cost |
| **Boot mode** | BIOS/UEFI | Auto detects |
| **Tenancy** | Shared/dedicated | Usually shared |
| **IAM instance profile** | Role for the new instance (SSM, CloudWatch) | Attach an SSM role |
| **Tags** | Add `Environment`, `Owner`, `map-migrated` | Always |

> Test and cutover instances use **the same Launch Settings**, so set them correctly before the first test.

---

## 9. Source Server Lifecycle

```
Not ready  ──(initial sync done)──▶  Ready for testing
                                          │ Launch test instances
                                          ▼
                                     Test in progress
                                          │ Mark as "Ready for cutover"
                                          ▼
                                     Ready for cutover
                                          │ Launch cutover instances
                                          ▼
                                     Cutover in progress
                                          │ Finalize cutover
                                          ▼
                                     Cutover complete   (replication stops, staging resources removed)
```

| State | Your action |
|---|---|
| **Not ready** | Wait for the initial sync |
| **Ready for testing** | Launch test instances |
| **Test in progress** | Validate the app, then **terminate test instances** and mark **Ready for cutover** |
| **Ready for cutover** | Schedule the window |
| **Cutover in progress** | Switch traffic, verify |
| **Cutover complete** | After you're sure, **Finalize cutover** (disconnects the source, deletes staging) |
| **Disconnected / Archived** | Done or removed |

---

## 10. Test → Cutover → Finalize

### Test (as many times as you like, no impact on the source)

```
1. Console → Source servers → select → Test and cutover → Launch test instances
2. MGN snapshots → conversion server runs → test EC2 instance starts (a few minutes)
3. Validate: login, services running, app works, data present, network/security groups correct
4. Terminate test instances  → "Mark as ready for cutover"
```

### Cutover (planned window)

```
Before:  Lag is low. Run a final test. Communicate the downtime. Lower DNS TTL in advance.
1. Stop writes at the source (stop the app/database, or shut down the server)
2. Wait for lag → 0 (final data synced)
3. Launch cutover instances
4. Validate quickly
5. Switch traffic (DNS / Route 53, load balancer, IP)
6. Keep the source powered off but intact for the rollback window
```

### Finalize

```
After the agreed stability period (for example 3–7 days):
  "Finalize cutover" → MGN stops replication and removes staging resources (saves cost)
  Then decommission the source.
```

**Rollback:** until you finalize and decommission, you can point traffic back to the source.

---

## 11. Post-Launch Actions

MGN can run **automated actions** on the launched instance (through **AWS Systems Manager**):

| Example action | Why |
|---|---|
| Install/configure **SSM Agent** | Management access |
| Install **CloudWatch agent** | Monitoring |
| Install **Inspector/security agent** | Compliance |
| Join to a domain | Active Directory |
| Uninstall the source's VMware Tools / vendor agents | Clean up |
| Custom script | Anything else |

Configure them under **Launch settings → Post-launch settings** (requires an SSM role on the instance).

---

## 12. Applications & Waves in MGN

```
Application = a group of source servers that migrate together    (for example "Customer Portal")
Wave        = a group of applications that cut over together
```

- Create applications and waves in MGN (console, CSV import, or API).
- Run **Test and cutover actions per wave**, so you launch all the wave's servers together.
- Add **notes/tags** and track the progress per wave.
- This mirrors the wave plan from `01_MAP_Framework_and_6Rs.md`, and the progress also shows in Migration Hub.

---

## 13. Agentless Option (vCenter)

For **VMware vSphere**, MGN offers **agentless replication** using a **vCenter Client** appliance with VMware snapshots:

| | **Agent-based** | **Agentless (vCenter)** |
|---|---|---|
| Install | Agent on every server | One appliance, no per-server install |
| Replication method | Block-level, continuous driver | VMware snapshot-based (CBT) |
| RPO | Seconds | Typically higher (snapshot cycles) |
| Source impact | Light, constant | Snapshot overhead on the VMware datastore |
| OS flexibility | Supported OS list | Any VM VMware can snapshot |
| Best for | Production needing low RPO, physical/other cloud | Many VMware VMs, where you can't touch the guest OS |

---

## 14. Assignment 2: Cross-Region Migration (Step by Step)

**Goal:** Create a source machine in **one region** and migrate it to **another region** with MGN. (An EC2 instance in region A plays the "on-prem" server.)

**Example:** Source = `us-east-1`, Target = `ap-south-1` (Mumbai). Use your sandbox account.

### Part A: Prepare the TARGET region (ap-south-1)

```
1. VPC "Target-VPC": 10.20.0.0/16
   ├─ Subnet "staging-subnet" 10.20.1.0/24  (public subnet for this lab, so the source can reach 1500 over the internet)
   └─ Subnet "app-subnet"     10.20.2.0/24
2. Internet Gateway attached, route table 0.0.0.0/0 → IGW
3. MGN → Get started → Initialize
   Replication settings template:
     Staging subnet: staging-subnet
     Replication server type: t3.small
     Public IP: ON (lab)  |  Security group: create new (allows 1500)
     EBS: Auto
4. IAM user "mgn-agent-install-user" with AWSApplicationMigrationAgentInstallationPolicy → create access key
```

### Part B: Create the SOURCE machine (us-east-1)

```
1. Launch EC2: Amazon Linux 2023 (or Ubuntu), t3.small, 20 GB, security group allows SSH (22) from your IP and HTTP (80)
2. SSH in and create something visible:
     sudo dnf install -y nginx && echo "SOURCE us-east-1" | sudo tee /usr/share/nginx/html/index.html
     sudo systemctl enable --now nginx
   Create a test file:  echo "data-$(date)" > ~/important.txt
3. Check outbound access to MGN (443) and the replication server (1500): default security group outbound is open
```

### Part C: Install the agent on the source

```
1. SSH to the source EC2
2. Download the installer from the TARGET region bucket (ap-south-1) per the MGN docs
3. Run:  sudo ./aws-replication-installer-init --region ap-south-1 --aws-access-key-id ... --aws-secret-access-key ...
4. Accept disk selection → installation finishes
```

### Part D: Watch replication

```
Target region console → MGN → Source servers → your server appears
Status: Initial sync → Backlog → Continuous data replication (Healthy)
Behind the scenes (EC2 in ap-south-1): a replication server (t3.small) and staging EBS volumes appear
```

### Part E: Configure launch settings

```
Source server → Launch settings
  Instance type right-sizing: ON  (or t3.small)
  Subnet: app-subnet, Security group: allow 80 from your IP, 22 from your IP
  Start instance upon launch: Yes
  Tags: Project=MGN-Lab
```

### Part F: Test

```
1. Test and cutover → Launch test instances
2. Wait for the test instance (EC2 in ap-south-1, "Launched by MGN")
3. Browse http://<test-instance-ip> → shows "SOURCE us-east-1" ✅
4. Verify ~/important.txt exists
5. Terminate test instance → Mark as ready for cutover
```

### Part G: Cutover and finalize

```
1. Stop writing on the source (sudo systemctl stop nginx)
2. Wait for replication lag ≈ 0
3. Launch cutover instance → verify
4. (Simulate DNS switch) point your test hostname/Route 53 record at the new IP
5. Finalize cutover → replication stops, staging resources are removed
```

### Part H: Clean up (avoid charges)

```
- Terminate the source EC2 (us-east-1) and the migrated EC2 (ap-south-1)
- Delete leftover EBS volumes/snapshots in ap-south-1
- Disconnect/archive the source server in MGN
- Delete the IAM user's access key and the IAM user
- Delete the VPC resources you created
```

### What to record
Time for the initial sync, the final lag, conversion time, and anything that blocked you. That is your "lessons learnt" report.

---

## 15. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Installer fails with access denied | Wrong key/policy/region | Check the IAM user policy, and use the region where MGN is initialized |
| Installer can't download | Outbound 443 blocked | Allow S3 and MGN endpoints |
| Server not appearing in MGN | Registration failed | Read the installer output and check the region |
| **Stuck at Initial sync / Stalled** | **Port 1500 blocked**, or the replication server is unreachable | Check the SG (1500 from source), NACLs, routes, and public/private IP setting |
| Very slow replication | Bandwidth, or a small replication server | Raise the instance type, check throttling, check VPN throughput |
| Lag keeps growing | Write-heavy source, or an undersized replication server | Bigger replication server instance, faster staging EBS |
| "Rescanning" often | Source reboots or disk issues | Stabilize the source, and check agent logs |
| Test instance won't boot | Driver/bootloader issue, unsupported OS | Check the Launch settings (boot mode), and the conversion logs |
| Test instance can't be reached | Wrong subnet/SG in Launch settings | Fix the launch template, and relaunch |
| Windows test instance has no network | Missing drivers, or a static IP config | Check ENA drivers, and the IP settings |
| Unexpected cost | Staging resources kept running | **Finalize cutover** or disconnect the server |

---

## 16. Corrections to the Existing MGN Notes

In `VPN_Setup_and_MGN_Migration.md` these points differ from how MGN works. **Please verify with the current AWS docs, then update that file.**

| In the old note | Should be |
|---|---|
| "Create IAM Role for MGN (Service: EC2, AWSApplicationMigrationMGN)" | A role can't be used by an on-prem VM. Create an **IAM user** with `AWSApplicationMigrationAgentInstallationPolicy` and an access key. MGN creates its own AWS-side roles |
| "Create Replication Server (optional pre-setup)" | You **don't create replication servers**. You **initialize MGN** and edit the **Replication Settings template**. MGN launches the replication servers |
| `sudo ./install.sh --region us-east-1` "using IAM role" | On-prem needs **access keys** |
| Agent name/URL (`replication-agent-installer.tar.gz`, `install.sh`) | Linux installer is `aws-replication-installer-init`, downloaded from the regional S3 bucket. Windows installer is `AwsReplicationWindowsInstaller.exe` |
| Missing ports | Add **TCP 443** (control) and **TCP 1500** (data) |
| Missing | Staging subnet, security group, conversion server, lifecycle states, post-launch actions |

---

## 17. Key Takeaways

```
1. MGN = continuous block-level replication → launch converted EC2 with minimal downtime.
2. Parts: Agent (source), MGN service, staging subnet, Replication Server, staging EBS, conversion server.
3. Agent needs IAM USER keys at install (not an EC2 role). MGN creates its own AWS-side roles.
4. Ports: 443 (control) and 1500 (data, TLS). Use private IP over VPN/Direct Connect for large or sensitive data.
5. Replication Settings template defines the staging area. Launch Settings define the target EC2.
6. Lifecycle: Not ready → Ready for testing → Test → Ready for cutover → Cutover → Finalize.
7. Test as often as needed, cut over in a window, and finalize only when stable (it removes staging and cost).
8. Group servers into applications and waves, and use post-launch actions for SSM/monitoring.
9. Troubleshoot "stuck" replication: ports (1500), routes, security groups, replication server size.
```

**Next note:** `05_AWS_Elastic_Disaster_Recovery.md`
