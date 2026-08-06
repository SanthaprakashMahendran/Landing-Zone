# On-Premises to AWS Migration Guide

## Your Scenario

```
Current State:
├── Server: Running in VMware (on-premises)
├── Location: Your data center
├── Resources: CPU, Memory, Storage
├── Network: On-prem network
└── Application: Running production workload

Goal:
├── Move to: AWS Cloud
├── Method: VMware → Amazon EC2
├── Downtime: Minimal or none
└── Result: Same server running in AWS
```

---

## How It Works (High Level)

### The Journey of Your VMware Server

```
On-Premises Data Center                AWS Cloud
┌─────────────────────────┐    ┌──────────────────────┐
│  Your VMware Server     │    │   Your AWS Server    │
│  ├─ OS (Windows/Linux)  │    │   ├─ OS (same)       │
│  ├─ Applications        │ ─→ │   ├─ Applications    │
│  ├─ Data                │    │   ├─ Data            │
│  ├─ Configuration       │    │   ├─ Configuration   │
│  └─ Disk Image          │    │   └─ Running live    │
└─────────────────────────┘    └──────────────────────┘

Process: Replicate everything → Transfer → Start in AWS
```

---

## Migration Strategies (Choose One)

### Strategy 1: Rehost (Lift & Shift)

**What:** Move server as-is to AWS
- Take VMware image → Convert → Run as EC2 instance
- Minimal changes to application
- Fastest migration

**Best For:**
- You want quick migration
- Application already works
- No re-architecture needed

**Timeline:** 1-2 weeks

```
VMware Server → Convert Image → EC2 Instance → Running
(Same OS, same apps, same config)
```

### Strategy 2: Replatform (Lift, Tinker & Shift)

**What:** Move to AWS + make small optimizations
- Migrate to EC2
- Switch to RDS instead of on-prem database
- Use AWS-native services

**Best For:**
- Want some cloud benefits
- Time for minor optimization
- Database migration

**Timeline:** 2-4 weeks

```
VMware + On-Prem DB → EC2 + RDS + Other AWS services
```

### Strategy 3: Refactor/Re-architect

**What:** Redesign application for cloud
- Containerize application
- Use Lambda, managed services
- Complete redesign

**Best For:**
- Want maximum cloud benefits
- Have time and budget
- Major modernization effort

**Timeline:** 2-3 months

```
On-Prem Monolith → Microservices → Lambda/ECS → Cloud-native
```

---

## For Your VMware Server: Rehost (Lift & Shift) Recommended

**Why?** It's the easiest path forward.

```
Step 1: Your VMware server (unchanged)
Step 2: Convert VMware image to AWS format
Step 3: Upload to AWS
Step 4: Start running as EC2
Step 5: Point traffic to AWS server
Step 6: Done!
```

---

## What Gets Migrated?

### Everything in Your VMware Server

```
VMware Server (On-Premises)
├── Operating System
│   └─ Windows Server 2019 / Linux Ubuntu / CentOS
├── Applications
│   ├─ Web server (Apache, IIS, Nginx)
│   ├─ Application runtime (Java, Python, .NET)
│   └─ Other software installed
├── Data
│   ├─ Application data
│   ├─ Configuration files
│   ├─ Logs
│   └─ Databases (if on same server)
├── Storage
│   ├─ Disk 1: OS + System files
│   ├─ Disk 2: Application files
│   └─ Disk 3: Data volumes
└── Network Configuration
    ├─ Network adapters
    ├─ IP configuration
    └─ Firewall rules
```

### What Happens to Each Component

```
Component                What Happens in AWS
─────────────────────────────────────────────
OS (Windows/Linux)    → Same OS (unchanged)
Applications          → Same applications (unchanged)
Data                  → Migrated to AWS storage
Storage               → AWS EBS (Elastic Block Store)
Network interfaces    → AWS Network interfaces
IP address            → New AWS elastic IP (or keep with VPN)
Firewall rules        → AWS Security Groups (same rules)
```

---

## Migration Process (Step-by-Step)

### Phase 1: Assessment (Week 1)

**What to document:**

1. **Server Details**
   ```
   Server Name: [e.g., web-server-01]
   OS: [Windows/Linux version]
   CPU: [8 vCPU]
   RAM: [16 GB]
   Storage: [500 GB total]
   Disk breakdown:
   ├─ C: 100 GB (OS)
   ├─ D: 300 GB (Application)
   └─ E: 100 GB (Data)
   ```

2. **Applications Running**
   ```
   Application 1: Nginx web server
   Application 2: Node.js application
   Application 3: MySQL database
   Application 4: Redis cache
   ```

3. **Network Configuration**
   ```
   IP Address: 192.168.1.100 (on-prem)
   Network: 192.168.1.0/24
   Gateway: 192.168.1.1
   DNS: 8.8.8.8
   Firewall: Opens ports 80, 443, 3306
   ```

4. **Data Dependencies**
   ```
   Database: MySQL (500 GB)
   Backup location: /backup/db.sql
   External connections: API calls to partner systems
   ```

5. **Downtime Tolerance**
   ```
   Can we have 1 hour downtime? YES/NO
   Can we have 10 min downtime? YES/NO
   Zero downtime required? YES/NO
   ```

### Phase 2: Planning (Week 1-2)

**Design AWS Architecture**

```
On-Premises                           AWS Cloud
┌──────────────┐                  ┌─────────────────┐
│ VMware       │                  │ VPC             │
│ Server       │                  │ ├─ Subnet 1     │
│ 192.168...   │──── VPN ────────→│ ├─ EC2 Instance │
│              │                  │ ├─ EBS Storage  │
│ OS: Linux    │                  │ └─ Sec Groups   │
│ Apps: Node   │                  └─────────────────┘
│ DB: MySQL    │
└──────────────┘                  
```

**AWS Setup Needed:**

1. **VPC (Virtual Private Cloud)**
   - Network space in AWS
   - Similar to on-prem network

2. **Subnet**
   - Where EC2 instance lives

3. **EC2 Instance**
   - Your migrated server

4. **EBS Volumes**
   - Storage for your server

5. **Security Group**
   - Firewall rules (port 80, 443, 3306)

6. **Network Connectivity**
   - VPN or Direct Connect to on-prem

### Phase 3: Pre-Migration Setup (Week 2-3)

#### Step 1: Create AWS VPC

```
In AWS Console:
1. Go to VPC
2. Create VPC
   ├─ Name: "On-Prem-Migration"
   ├─ CIDR: 10.0.0.0/16 (must not conflict with on-prem 192.168.1.0/24)
   └─ Create

3. Create Subnet
   ├─ Name: "Migration-Subnet"
   ├─ VPC: "On-Prem-Migration"
   ├─ CIDR: 10.0.1.0/24
   └─ Create
```

#### Step 2: Create EC2 Instance (Template)

```
In AWS Console:
1. Go to EC2
2. Launch Instance
   ├─ Type: Depends on your server
   ├─ If Linux 8-core: t3.2xlarge or c5.2xlarge
   ├─ If Windows similar: m5.2xlarge
   ├─ Storage: 500 GB (matching on-prem)
   ├─ VPC: "On-Prem-Migration"
   └─ Subnet: "Migration-Subnet"
```

#### Step 3: Setup VPN (Connect On-Prem to AWS)

```
In AWS Console:
1. Go to VPN Gateway
2. Create Customer Gateway
   ├─ Name: "On-Prem-VMware"
   ├─ IP Address: Your on-prem gateway IP
   └─ Create

3. Create VPN Connection
   ├─ Name: "On-Prem-to-AWS"
   ├─ Type: Site-to-Site VPN
   ├─ Attach to VGW (Virtual Private Gateway)
   └─ Create

4. In Your Firewall/Router
   ├─ Configure VPN to AWS
   ├─ Route traffic from 192.168.1.0/24 → 10.0.0.0/16 via VPN
   └─ Test connectivity
```

**Result:** On-prem and AWS can now talk to each other

---

### Phase 4: Actual Migration (Week 3-4)

#### Migration Tool: AWS MGN (Application Migration Service)

**What MGN does:**
1. Connects to your VMware server
2. Copies disk image continuously
3. Keeps AWS copy updated
4. Allows cutover when ready

#### Step 1: Install MGN Replication Agent

On your **VMware server**:

```
On Linux:
$ wget https://aws.mgn.com/agent.tar.gz
$ tar -xzf agent.tar.gz
$ sudo ./install.sh --region us-east-1 --role migration-role

On Windows:
- Download installer from AWS console
- Run MGNAgent-windows-installer.exe
- Configure with AWS credentials
```

**What it does:**
- Connects to AWS
- Starts replicating your disk
- Copies all data continuously

#### Step 2: Monitor Replication

```
In AWS MGN Console:
├─ Server "web-server-01"
├─ Status: "Replicating"
├─ Replication Progress: 45% → 67% → 89% → 100%
├─ Data replicated: 450 GB / 500 GB
└─ Replication lag: 2 seconds (means AWS copy is 2 seconds behind)
```

**Timeline:** 1-8 hours depending on data size and network speed

---

### Phase 5: Pre-Cutover Testing (Day Before Cutover)

#### Test in AWS Before Switching

```
In AWS MGN Console:
1. Click "Launch Test Instance"
   ├─ AWS creates temporary EC2 from migrated image
   ├─ Disk fully replicated to EBS
   ├─ Instance starts
   └─ Same OS, apps, data as on-prem

2. Test the instance:
   ├─ SSH/RDP into EC2 instance
   ├─ Check OS is correct ($ uname -a or ipconfig)
   ├─ Check applications running ($ ps aux)
   ├─ Check data present ($ ls -la /data/)
   ├─ Test application (curl, browser, database query)
   └─ If all works → Good to proceed

3. If issues found:
   ├─ Note the problem
   ├─ Terminate test instance
   ├─ Fix on on-prem server
   ├─ Wait for replication to catch up
   └─ Test again

4. Once confirmed working:
   └─ Terminate test instance
```

---

### Phase 6: Cutover (The Big Moment!)

**Cutover Window:** Saturday 2 AM (low traffic)

#### Before Cutover (30 min prior)

```
Checklist:
✓ VPN connection working
✓ Test instance passed
✓ All applications verified
✓ Database backups taken
✓ Team on standby
✓ Rollback plan ready
```

#### Cutover Steps (15 minutes)

```
T - 10 min: Stop all traffic to on-prem server
            └─ Stop accepting new requests
            └─ Let existing connections drain

T - 5 min:  Verify replication lag is 0 seconds
            └─ AWS copy is exactly same as on-prem
            └─ All data transferred

T - 0 min:  Click "Finalize Cutover" in AWS MGN
            ├─ Creates final EC2 instance in AWS
            ├─ Stops on-prem server
            ├─ Starts AWS server
            ├─ Allocates Elastic IP (public IP)
            └─ Ready to receive traffic

T + 1 min:  Update DNS
            ├─ Change DNS to point to AWS IP
            ├─ Or update application config
            ├─ Traffic now goes to AWS server

T + 5 min:  Monitor
            ├─ Watch AWS CloudWatch metrics
            ├─ Watch application logs
            ├─ Monitor error rates
            └─ Check if customers seeing service

T + 30 min: Verify success
            ├─ All transactions working
            ├─ No data loss
            ├─ Performance acceptable
            └─ If OK → Migration successful!
```

---

### Phase 7: Post-Migration (Week 4+)

#### Validation

```
Checklist:
✓ All applications running
✓ All data present
✓ No data loss
✓ Performance acceptable
✓ Backups configured
✓ Monitoring configured
✓ On-prem server still running (backup)
```

#### Keep On-Prem as Backup (48-72 hours)

```
Days 1-3: On-prem server stays ON
├─ In case we need to rollback
├─ As backup in case AWS has issues
├─ Monitor AWS, not using on-prem

Day 4+: Can safely shut down on-prem
├─ Confident AWS is stable
├─ All monitoring in place
├─ Decommission on-prem server
```

#### Decommissioning On-Prem Server

```
Week 5:
├─ Take final backup from AWS
├─ Archive on-prem data (if needed)
├─ Shut down VMware server
├─ Remove from VMware inventory
├─ Deallocate hardware (sell, recycle)
├─ Return rack space
└─ Cost savings begin!
```

---

## Tools Used in Migration

### AWS MGN (Application Migration Service)

**Purpose:** Replicates your on-prem server to AWS

**How it works:**
1. Install agent on your server
2. Continuously copies disk blocks
3. Creates EC2 instance when ready
4. Minimal downtime cutover

**Cost:** Usually ~$0.5-2 per server per month during migration

### AWS DataSync

**Purpose:** Transfer large amounts of data quickly

**Used for:**
- Large databases (> 100 GB)
- Bulk file transfers
- Separate from server migration

### VMware vSphere Replication

**Alternative:** If already using VMware

**Advantage:** VMware-native replication

---

## Real Example: Your Migration

### Before: On-Prem

```
Server: web-prod-01 (Your VMware Server)
├── OS: Ubuntu 20.04
├── CPU: 8 vCPU
├── RAM: 16 GB
├── Storage: 500 GB
│   ├─ 100 GB: OS + System
│   ├─ 200 GB: Node.js application
│   └─ 200 GB: PostgreSQL database
├── Applications
│   ├─ Nginx (web server)
│   ├─ Node.js application
│   ├─ PostgreSQL database
│   └─ Redis cache
└── Network: 192.168.1.100, Port 80, 443, 5432
```

### Migration Steps (Your Server)

```
Week 1: Assessment
├─ Document: 8 vCPU, 16 GB RAM, 500 GB storage
├─ Document: Ubuntu, Node.js, PostgreSQL
├─ Document: Port 80, 443, 5432 open
└─ Decide: Rehost (lift & shift) strategy

Week 2: AWS Setup
├─ Create VPC (10.0.0.0/16)
├─ Create Subnet (10.0.1.0/24)
├─ Setup VPN to on-prem
├─ Create security group (allow 80, 443, 5432)
└─ Ready for migration

Week 3: Replication
├─ Install MGN agent on web-prod-01
├─ Start replication
├─ Monitor: 0% → 50% → 100%
├─ Size: 500 GB uploaded to AWS
├─ Time: ~4 hours
└─ Replication lag: <1 second

Day Before: Test
├─ Launch test instance
├─ SSH into AWS server
├─ $ uname -a → Ubuntu ✓
├─ $ node --version → v14.x.x ✓
├─ $ psql -c "SELECT COUNT(*) FROM users" → 1M records ✓
├─ $ curl localhost → Page loads ✓
├─ Terminate test instance
└─ Ready for cutover

Cutover Day (Saturday 2 AM):
├─ T-10min: Stop traffic to on-prem
├─ T-5min: Verify replication lag = 0
├─ T-0min: Click "Finalize Cutover"
├─ T+1min: Update DNS to AWS IP
├─ T+5min: Monitor metrics
├─ T+30min: Verify all working
└─ Migration complete! ✓

Post-Migration:
├─ Day 1-3: On-prem as backup
├─ Day 4+: Confident AWS is stable
├─ Week 2: Decommission on-prem server
└─ Savings: $2000/month (hardware, energy, maintenance)
```

### After: AWS

```
Server: web-prod-01 (Now in AWS)
├── OS: Ubuntu 20.04 (same)
├── EC2 Type: c5.2xlarge (8 vCPU, 16 GB)
├── EBS Storage: 500 GB gp3
│   ├─ 100 GB: OS + System
│   ├─ 200 GB: Node.js application
│   └─ 200 GB: PostgreSQL database
├── Applications (same)
│   ├─ Nginx
│   ├─ Node.js
│   ├─ PostgreSQL
│   └─ Redis
├── Network: 10.0.1.50, Port 80, 443, 5432
├── Monitoring: CloudWatch enabled
├── Backups: Automated daily
└── Failover: Multi-AZ ready
```

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Replication slow** | Large data + slow network | Use AWS DataSync, increase bandwidth |
| **Cutover failed** | Replication not complete | Wait for lag=0, retry |
| **App doesn't start** | OS/driver differences | Check MGN parameters, fix on-prem, resync |
| **Network unreachable** | VPN not configured | Check VPN, security groups, firewall rules |
| **Performance poor** | Wrong instance type | Resize EC2 to match on-prem specs |

---

## Cost Analysis

### On-Premises (Per Month)

```
Hardware: $2000
├─ Server lease/amortization
├─ Maintenance
└─ Support

Power & Cooling: $300
Network: $200
Storage: $500
├─ Backup storage
└─ Redundancy

Total: ~$3000/month
```

### AWS (Per Month)

```
EC2 (c5.2xlarge, 730 hours): $1200
EBS (500 GB gp3): $150
Data Transfer: $50 (if applicable)
Total: ~$1400/month

Savings: $1600/month (53% reduction!)
```

---

## Summary of Your Migration Path

```
Your VMware Server (On-Prem)
        ↓
    Assess (Document specs, apps, network)
        ↓
    Plan (Choose AWS architecture, VPC, subnet)
        ↓
    Prepare (Create VPC, subnet, security groups, VPN)
        ↓
    Replicate (Install MGN, copy 500 GB to AWS)
        ↓
    Test (Launch test instance, verify everything)
        ↓
    Cutover (Switch traffic from on-prem to AWS)
        ↓
    Validate (Monitor, verify success)
        ↓
    Decommission (Turn off on-prem server)
        ↓
    Your AWS Server Running Live!
```

---

## Timeline for Your Migration

```
Week 1: Planning & Assessment (20 hours)
Week 2: AWS Infrastructure Setup (16 hours)
Week 3: Replication & Testing (24 hours)
Week 4: Cutover & Validation (8 hours)
Week 5: Optimization (ongoing)

Total: 4-5 weeks for complete migration
```

---

## Key Takeaways

1. **Rehost is easiest** — Lift & shift from VMware to EC2
2. **MGN automates it** — Handles replication and cutover
3. **Test before cutover** — Launch test instance to verify
4. **Cutover takes minutes** — Not hours (with proper setup)
5. **Keep backup 48-72 hours** — Rollback plan in place
6. **Cost savings significant** — Usually 50% reduction
7. **Zero downtime possible** — With proper planning

---

## Next Steps

To start YOUR migration:

1. ✅ Document your VMware server specs
2. ✅ Identify applications and databases
3. ✅ Plan AWS VPC architecture
4. ✅ Create AWS account & setup
5. ✅ Install MGN agent
6. ✅ Monitor replication
7. ✅ Test before cutover
8. ✅ Execute cutover
9. ✅ Validate and optimize
10. ✅ Decommission on-prem

Ready to dive deeper into any specific phase?
