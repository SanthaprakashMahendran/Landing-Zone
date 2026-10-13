# AWS Data Transfer & Hybrid Storage Services

S3 · DataSync · Storage Gateway · Direct Connect · Snow Family (Snowcone, Snowball, Snowmobile) · Choosing the Right One

> Details such as device capacities, prices and service availability change. Check the AWS pages for current numbers before you plan.

---

## Table of Contents
1. The Core Question: How Do I Get the Data There?
2. Do the Math First (Transfer Time)
3. Amazon S3 (The Destination for Most Data)
4. AWS DataSync
5. AWS Storage Gateway
6. AWS Direct Connect
7. AWS Site-to-Site VPN (Recap)
8. AWS Snow Family (Offline Transfer)
9. AWS Transfer Family (SFTP/FTPS/FTP)
10. Other Options (CLI, Transfer Acceleration, MGN/DMS)
11. Decision Guide
12. Security for Data in Motion
13. Real Examples
14. Troubleshooting
15. Key Takeaways

---

## 1. The Core Question: How Do I Get the Data There?

Servers (MGN) and databases (DMS) have their own replication. This note is about **bulk data**: file shares, archives, backups, data lakes, media, logs.

```
Two decisions:
1. ONE-TIME migration or ONGOING sync?
2. ONLINE (over the network) or OFFLINE (ship a device)?
```

---

## 2. Do the Math First (Transfer Time)

```
Time = Data size ÷ usable bandwidth
Usable bandwidth ≈ 70–80% of the link
```

| Data | 100 Mbps | 1 Gbps | 10 Gbps |
|---|---|---|---|
| 1 TB | ~1.2 days | ~2.8 hours | ~17 min |
| 10 TB | ~12 days | ~1.2 days | ~3 hours |
| 100 TB | ~4 months | ~12 days | ~1.2 days |
| 1 PB | ~3 years | ~4 months | ~12 days |

(Rounded, assuming ~80% efficiency. 1 TB = 8 Tb; 8 × 10¹² bits ÷ 80 Mbps ≈ 100,000 s ≈ 1.2 days.)

### Rule of thumb
- If the transfer would take **more than ~1–2 weeks** on your link, consider **Snow** (offline) or **Direct Connect**.
- Remember the link is **shared** with production traffic, so plan to **throttle** the transfer.

---

## 3. Amazon S3 (The Destination for Most Data)

### What it is
Object storage: virtually unlimited, durable (11 nines), pay-per-use. The usual **landing zone for bulk data**, and the target for DataSync, Storage Gateway, Snow and Transfer Family.

### Storage classes (choose by access pattern)

| Class | Use | Retrieval |
|---|---|---|
| **S3 Standard** | Frequently accessed data | Instant |
| **S3 Intelligent-Tiering** | Unknown/changing access | Instant, automatic tiering |
| **S3 Standard-IA / One Zone-IA** | Infrequent access | Instant, retrieval fee |
| **S3 Glacier Instant Retrieval** | Archive, with millisecond access | Instant |
| **S3 Glacier Flexible Retrieval** | Archive, minutes to hours | Minutes–hours |
| **S3 Glacier Deep Archive** | Longest-term, cheapest | ~12 hours |

Use **lifecycle rules** to move data between classes automatically.

### Moving data into S3 with the CLI

```bash
aws s3 cp bigfile.iso s3://my-bucket/               # single file (multipart automatic)
aws s3 sync /data s3://my-bucket/data --storage-class STANDARD_IA
aws configure set default.s3.max_concurrent_requests 20   # speed up parallel transfers
```

### Speed features

| Feature | Detail |
|---|---|
| **Multipart upload** | Large files split into parts, in parallel and resumable |
| **S3 Transfer Acceleration** | Uses CloudFront edge locations for long-distance uploads (extra charge) |
| **Parallelism** | Many files at once (`sync`, DataSync) beat one big stream |

### Security
Block Public Access, bucket policies, **SSE-S3/SSE-KMS** encryption, versioning, **Object Lock** for compliance.

---

## 4. AWS DataSync

### What it is
A managed service that **moves large amounts of file/object data** between on-prem (or other clouds) and AWS storage, **faster and with less effort than DIY scripts** (`rsync`/`robocopy`).

```
On-prem NFS / SMB / HDFS / object storage
        │  DataSync Agent (VM on VMware/Hyper-V/KVM, or EC2)
        │  encrypted, parallel, optimized protocol  (over internet, VPN, or Direct Connect)
        ▼
S3 · EFS · FSx (Windows File Server / Lustre / NetApp ONTAP / OpenZFS)
```

### Key features

| Feature | Detail |
|---|---|
| **Agent** | A VM you deploy next to the source storage |
| **Locations** | Source and destination definitions (NFS, SMB, S3, EFS, FSx...) |
| **Task** | A copy job: source → destination, with filters, schedule and options |
| **Scheduling** | One-time, or **recurring** (hourly/daily) for ongoing sync |
| **Incremental** | Only changed files after the first run |
| **Verification** | Checks data integrity after transfer |
| **Bandwidth limit** | Throttle to protect production |
| **Metadata** | Preserves permissions, timestamps and ownership where supported |
| **Monitoring** | CloudWatch metrics and logs |
| **Network paths** | Public endpoint, **VPC endpoint (PrivateLink)** for private-only transfers |

### Flow

```
1. Deploy the DataSync agent VM on-prem (download the image from the console)
2. Activate the agent (links it to your AWS account/region)
3. Create the source location (for example NFS server + path)
4. Create the destination location (for example S3 bucket + IAM role)
5. Create the task (include/exclude filters, schedule, bandwidth limit, verification)
6. Start the task, and monitor the throughput
7. Final run on cutover day (a small delta), then switch applications to use AWS storage
```

### DataSync vs alternatives

| | `aws s3 sync` / rsync | **DataSync** |
|---|---|---|
| Setup | None | Agent + task |
| Speed on large datasets | Single-host limits | Parallel, optimized |
| Scheduling/monitoring | DIY | Built in |
| Integrity checks | DIY | Built in |
| File metadata | Limited | Preserved |
| Cost | Free | Per-GB transferred |

> Your migration notes already say **"use DataSync if replication is slow with big data"**. This is the detail behind that line. For **servers**, use MGN. For **files and shares**, use DataSync.

---

## 5. AWS Storage Gateway

### What it is
A **hybrid storage** service: a **gateway appliance** (VM, hardware appliance, or EC2) that gives your on-prem apps **local, standard protocols**, backed by **AWS storage**. It's for **ongoing hybrid use**, not just a one-time move.

```
On-prem apps ──(NFS / SMB / iSCSI / VTL)──▶ Gateway (local cache) ──▶ S3 / EBS snapshots / Glacier
```

### Gateway types

| Type | Presents | Backed by | Use |
|---|---|---|---|
| **S3 File Gateway** | NFS/SMB file shares | **S3 objects** (1 file = 1 object) | File shares and backups into S3, data lake ingestion, replacing on-prem NAS growth |
| **FSx File Gateway** | SMB shares | **FSx for Windows File Server** | Low-latency local access to FSx Windows shares |
| **Volume Gateway** | iSCSI block volumes | **EBS snapshots in S3** | **Cached volumes** (hot data local) or **stored volumes** (full copy local, async to AWS) for DR/backup |
| **Tape Gateway** | Virtual tape library (VTL) | S3 + **Glacier/Deep Archive** | Replace physical tape backup (works with Veeam, Veritas, etc.) |

### How it behaves
- **Local cache** gives low-latency reads for hot data, and writes are uploaded asynchronously to AWS.
- Data in S3 is readable natively by AWS services (analytics, Lambda, etc.), which is useful for **data lake** feeding.
- Needs sufficient local disk for the cache, and bandwidth for upload.

### Storage Gateway vs DataSync

| | **DataSync** | **Storage Gateway** |
|---|---|---|
| Purpose | **Move/sync** data (migration, replication) | **Ongoing hybrid access** |
| After migration | Applications use AWS storage directly | On-prem apps keep using the gateway as a bridge |
| Typical use | "Move 50 TB file share to S3/FSx" | "Keep file shares on-prem with cloud backing and cache" |

---

## 6. AWS Direct Connect

### What it is
A **dedicated private network connection** from your data center to AWS (not over the public internet). More **consistent latency**, higher **bandwidth**, and often **lower data-transfer costs** than internet/VPN.

```
Your data center ──(cross-connect at a Direct Connect location)──▶ AWS (Direct Connect location) ──▶ your VPCs / AWS public services
```

### Connection types

| Type | Speeds | Notes |
|---|---|---|
| **Dedicated Connection** | 1, 10, 100 Gbps | You get a physical port at a DX location |
| **Hosted Connection** | Sub-1 Gbps up to higher (via partners) | Ordered through an AWS Direct Connect Partner, so it's faster to get |

### Virtual interfaces (VIFs)

| VIF | Reaches | Use |
|---|---|---|
| **Private VIF** | A VPC (via a Virtual Private Gateway or **Direct Connect Gateway**) | Private IP access to VPC workloads |
| **Public VIF** | AWS public endpoints (S3, DynamoDB, etc.) | Bulk transfer to S3 over the private link |
| **Transit VIF** | **Transit Gateway** (via a DX Gateway) | Many VPCs/accounts, which fits a landing zone |

### Key points

| Topic | Detail |
|---|---|
| **Lead time** | Often **weeks** (cross-connect, partner provisioning) |
| **Resilience** | One connection = a single point of failure. Use **two connections at different locations**, and a **VPN as backup** |
| **Encryption** | **Not encrypted by default.** Add **IPsec VPN over Direct Connect**, or **MACsec** on supported dedicated connections |
| **Routing** | BGP, with a DX Gateway to reach multiple regions/VPCs |
| **Cost** | Port-hours + data transfer out (cheaper than internet egress) |
| **LAG** | Bundle multiple connections for more bandwidth |

### Direct Connect vs VPN

| | **Site-to-Site VPN** (your notes) | **Direct Connect** |
|---|---|---|
| Path | Public internet (IPsec) | Private dedicated link |
| Setup time | Minutes–hours | Weeks |
| Bandwidth | Up to ~1.25 Gbps per tunnel | 1–100 Gbps |
| Consistency | Variable | Consistent |
| Cost | Low | Higher fixed cost, lower per-GB |
| Best for | Start quickly, small/medium migrations, backup path | Large ongoing transfers, production hybrid networks |

**Typical pattern:** start with **VPN** (fast), add **Direct Connect** for heavy or permanent traffic, and keep the **VPN as backup**.

---

## 7. AWS Site-to-Site VPN (Recap)

(Covered step by step in `VPN_Setup_and_MGN_Migration.md`.)

- Two IPsec tunnels per connection, BGP or static routes
- Encrypted over the internet, quick to set up
- Used for MGN/DMS replication traffic (private IP path) and management access
- Throughput limits per tunnel (use **ECMP with Transit Gateway** to aggregate)

---

## 8. AWS Snow Family (Offline Transfer)

### What it is
**Ruggedized devices AWS ships to you.** You load data locally, ship them back, and AWS imports it into S3. Best when **the network is too slow, too expensive, or unavailable**.

```
1. Order a device in the console (choose S3 bucket destination)
2. AWS ships it to you
3. Connect it to your network, and copy the data (Snowball client / S3 interface / NFS)
4. Ship it back (the shipping label is on the e-ink display)
5. AWS ingests the data into S3 (you see status in the console)
```

### Devices (check current specs)

| Device | Approx. capacity | Use |
|---|---|---|
| **Snowcone** | A few TB (HDD or SSD), small and light | Edge/remote sites, small data, or send data back online with DataSync |
| **Snowball Edge Storage Optimized** | Tens to hundreds of TB | Bulk data migration (tens–hundreds of TB per device) |
| **Snowball Edge Compute Optimized** | Less storage, more compute (GPU option) | Edge processing + data collection |
| **Snowmobile** | **Exabyte-scale** (a truck-mounted container) | Data center-scale migrations. *AWS has been winding this down, so confirm availability.* |

(Capacities and model names change. Check the **Snow Family** page.)

### Features
- **Encryption** on the device (256-bit), with keys managed through AWS KMS (keys aren't stored on the device)
- **Tamper-resistant**, with tracking and a chain of custody
- Multiple devices in a **cluster** for more capacity/durability
- Some models can run **EC2 instances/Lambda at the edge**

### When to choose Snow

| Situation | Use Snow? |
|---|---|
| 50 TB over a 100 Mbps link (about 6 weeks online) | ✅ Yes |
| Remote site with no reliable network | ✅ Yes |
| Network is fast and idle | ❌ DataSync/online is simpler |
| Need continuous sync | ❌ Use DataSync/Storage Gateway/DX |
| **Hybrid approach:** Snow for the **bulk**, then **DataSync/online** for the **delta** | ✅ Very common |

### Hybrid pattern

```
Week 0:  Snowball ships 80 TB (bulk copy happens while the business runs)
Week 2:  Data lands in S3
Week 2+: DataSync/online sync copies only what changed since the Snowball copy
Cutover: final small delta, switch the applications
```

---

## 9. AWS Transfer Family (SFTP/FTPS/FTP)

For partners/legacy systems that **send files via SFTP/FTPS/FTP**:

```
Partners ──SFTP──▶ AWS Transfer Family endpoint ──▶ S3 (or EFS)
```

- Managed, highly available servers, no SFTP servers to patch
- Integrates with your identity systems (service-managed users, AD, custom IdP via Lambda/API Gateway)
- Good for replacing on-prem SFTP servers during a migration

---

## 10. Other Options (CLI, Transfer Acceleration, MGN/DMS)

| Need | Tool |
|---|---|
| Whole **servers** | **MGN** (note 04) |
| **Databases** | **DMS** (+SCT) (note 06) |
| **Files/shares** (one-time or scheduled) | **DataSync** |
| **Small ad-hoc** uploads | `aws s3 cp/sync` |
| **Long-distance uploads** from many clients | **S3 Transfer Acceleration** |
| **Ongoing hybrid access** | **Storage Gateway** |
| **Huge or offline** data | **Snow** |
| **Partner file exchange** | **Transfer Family** |
| **Backups** | **AWS Backup**, Storage Gateway Tape/Volume, or a vendor with S3 targets |

---

## 11. Decision Guide

```
What are you moving?
├─ A server (OS + apps) ───────────────────────▶ MGN
├─ A database ─────────────────────────────────▶ DMS (+SCT) / native tools
└─ Files / object data
    │
    Do the math: how long over your link?
    ├─ Under ~1–2 weeks ──────────────────────────────┐
    │    One-time or scheduled sync?                  │
    │    ├─ Yes ─▶ DataSync (agent, scheduled, verify)│  ← most common
    │    └─ Small/simple ─▶ aws s3 sync               │
    ├─ Weeks to months, or network unavailable ──────▶ Snow Family (bulk) + DataSync (delta)
    ├─ Need a permanent, high-throughput private link ▶ Direct Connect (+ VPN backup)
    └─ On-prem apps must KEEP using local file/block/tape protocols, backed by AWS
                                                     ▶ Storage Gateway (File / Volume / Tape)
```

### Quick table

| Scenario | Best fit |
|---|---|
| Move a 20 TB file share to S3/FSx over a VPN | **DataSync** |
| Move 300 TB from a remote office with a slow link | **Snowball Edge** |
| Keep the NAS on-prem but extend into S3 and stop buying disks | **S3 File Gateway** |
| Replace tape backups | **Tape Gateway** |
| Replicate production data nightly to AWS | **DataSync** (scheduled) or app-level replication |
| Stable, heavy, permanent hybrid traffic | **Direct Connect** |
| Partners push files via SFTP | **Transfer Family** |

---

## 12. Security for Data in Motion

| Control | Detail |
|---|---|
| **Encryption in transit** | TLS (DataSync, S3, MGN), IPsec (VPN), MACsec/VPN-over-DX for Direct Connect |
| **Encryption at rest** | SSE-S3/SSE-KMS (S3), KMS keys for EBS/EFS/FSx, Snow devices encrypt by default |
| **Private paths** | **VPC endpoints** (S3 gateway endpoint, DataSync/PrivateLink interface endpoints) so traffic avoids the public internet |
| **Least privilege** | Dedicated IAM roles for DataSync locations and Storage Gateway |
| **Integrity** | DataSync verification, S3 checksums (`--checksum-algorithm`), Snow import reports |
| **Auditing** | CloudTrail, S3 access logs, CloudWatch |
| **Compliance** | Data residency, region choice, retention (Object Lock) |

---

## 13. Real Examples

### Example 1: 40 TB file server to S3 over VPN (DataSync)

```
Link: 500 Mbps VPN (usable ~400 Mbps) → 40 TB ≈ 9–10 days
Plan:
  Day 0   Deploy the DataSync agent VM, create NFS → S3 task, throttle to 250 Mbps in business hours
  Day 1–10 Initial copy
  Daily   Scheduled incremental runs
  Cutover Final run, remount applications to S3/FSx (or deploy a File Gateway)
```

### Example 2: 200 TB from a remote site (Snow + DataSync)

```
Order 3 × Snowball Edge Storage Optimized → copy → ship (about 1–2 weeks incl. shipping)
Data lands in S3 → DataSync handles changes made during transit
```

### Example 3: Hybrid backup (Tape Gateway)

```
Backup software (Veeam/NetBackup) writes to a virtual tape library → Tape Gateway → S3 Glacier Deep Archive
Cheaper, durable, no tape handling
```

### Example 4: Permanent hybrid network for the migration program

```
Phase 1: Site-to-Site VPN (week 1) → start MGN/DMS replication
Phase 2: Direct Connect 1 Gbps (arrives week 6) → move heavy data; VPN stays as backup
Phase 3: Transit Gateway + DX Gateway → all landing-zone VPCs reachable from on-prem
```

---

## 14. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| DataSync task slow | Link saturated, bandwidth limit set, small files overhead | Check the throttle, increase agent resources (vCPU/RAM), run multiple tasks in parallel |
| DataSync agent won't activate | Network/ports (443, activation endpoint) | Open the required outbound ports to the DataSync endpoints or VPC endpoint |
| `Access denied` writing to S3 | IAM role/bucket policy | Fix the DataSync location role and bucket policy |
| Files missing at the destination | Filters/excludes, permissions on the source | Review the task filters and the source read access |
| Storage Gateway slow | Cache too small, upload bandwidth low | Add cache disks, check bandwidth |
| Gateway can't reach AWS | Proxy/firewall, DNS | Allow outbound 443 and the needed endpoints |
| Direct Connect BGP down | VLAN/ASN/IP mismatch, physical issue | Check the VIF config, LOA-CFA, and the cross-connect status |
| VPN tunnel flapping | Dead peer detection, ISP issues | Check IKE/IPsec settings, and use both tunnels |
| Snow device transfer slow | 1 GbE link, many small files | Use 10/25 GbE, batch small files into archives, parallel copy |
| S3 `Slow Down` (503) errors | Very high request rate on one prefix | Spread across prefixes, use retries/backoff |
| Surprise egress charges | Pulling data back out of AWS | Estimate transfer-out cost before designing the flows |

---

## 15. Key Takeaways

```
1. Do the math first: size ÷ usable bandwidth decides online vs offline.
2. S3 is the main landing zone. Pick storage classes and lifecycle rules.
3. DataSync = move/sync files at scale (agent, scheduled tasks, verification, throttling).
4. Storage Gateway = ongoing hybrid access (File, Volume, Tape) with a local cache.
5. Direct Connect = dedicated private link (weeks to order, not encrypted by default). Keep a VPN as backup.
6. Snow Family = ship devices for huge/remote data, then use DataSync for the delta.
7. MGN is for servers, DMS for databases, and these tools are for files and bulk data.
8. Protect data in motion with TLS/IPsec/MACsec, VPC endpoints, least-privilege IAM and CloudTrail.
```

**Back to the index:** `README.md`
