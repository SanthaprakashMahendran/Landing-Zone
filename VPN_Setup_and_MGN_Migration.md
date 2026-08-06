# Site-to-Site VPN + MGN Migration Guide

## Why Do We Need Site-to-Site VPN?

### Without VPN (Not Secure)
```
Your VMware Server          AWS EC2
    (On-Prem)              (AWS VPC)
        │                      │
        └─────Internet─────────┘
        
Problem:
- Traffic travels over public internet
- Anyone can intercept
- Not suitable for internal communication
- Databases, passwords exposed
```

### With Site-to-Site VPN (Secure)
```
Your VMware Server          AWS EC2
    (On-Prem)              (AWS VPC)
        │                      │
        └─ Encrypted IPSec ────┘
        
Benefits:
- Encrypted tunnel
- Private communication
- Data safe from interception
- Suitable for sensitive data
```

---

## VPN Components

### 1. Virtual Private Gateway (VGW)
```
What: AWS's VPN endpoint (AWS's router)
Where: Attached to your VPC
Job: 
  ├─ Terminate VPN tunnel
  ├─ Encrypt outgoing traffic
  ├─ Decrypt incoming traffic
  ├─ Exchange routes with on-prem
  └─ Forward traffic into VPC
```

### 2. Customer Gateway (CGW)
```
What: AWS object storing info about your on-prem VPN device
Who creates: You (AWS doesn't create your actual router)
Example:
  ├─ Device: Cisco ASA / Fortinet / pfSense
  ├─ Public IP: 203.0.113.10
  └─ AWS records this information
```

### 3. Site-to-Site VPN Connection
```
What: Encrypted IPSec tunnel between CGW and VGW
AWS creates: 2 tunnels for high availability
  ├─ Tunnel 1: Active
  └─ Tunnel 2: Backup (if Tunnel 1 fails)
```

### 4. BGP (Border Gateway Protocol)
```
What: Dynamic routing protocol
Job: Exchange networks between on-prem and AWS
  ├─ On-prem advertises: 192.168.1.0/24
  └─ AWS advertises: 10.0.0.0/16
Benefit: Automatic failover, no manual route updates
```

---

## Step-by-Step: Create Site-to-Site VPN in AWS Console

### Prerequisites

Before starting, gather:
```
On-Premises Information:
├─ Router's Public IP: 203.0.113.10 (example)
├─ On-Prem Network: 192.168.1.0/24
├─ Router Model: Cisco ASA / Fortinet / pfSense / etc.
├─ ASN (Autonomous System Number): 65000 (for BGP)
└─ Pre-Shared Key: (optional, AWS can generate)

AWS Information:
├─ VPC ID: vpc-xxxxx
├─ VPC CIDR: 10.0.0.0/16
├─ Region: us-east-1
└─ ASN: 64512 (AWS default)
```

### Step 1: Create Virtual Private Gateway (VGW)

In **AWS Console:**

```
1. Go to: VPC → Virtual Private Gateways
2. Click: "Create virtual private gateway"
3. Fill in:
   ├─ Name: "Migration-VGW"
   ├─ ASN: "64512" (default AWS ASN, can be custom)
   └─ Click: "Create virtual private gateway"

4. VGW is created
   └─ Status: Initially "pending" → then "available"
```

### Step 2: Attach VGW to VPC

```
1. Select the VGW you just created
2. Click: "Attach to VPC"
3. Choose:
   ├─ VPC: Select your VPC (e.g., "On-Prem-Migration")
   └─ Click: "Attach"

4. Result:
   └─ VGW now attached to your VPC
```

### Step 3: Create Customer Gateway (CGW)

```
1. Go to: VPC → Customer Gateways
2. Click: "Create customer gateway"
3. Fill in:
   ├─ Name: "On-Prem-VMware-Router"
   ├─ BGP ASN: "65000" (your on-prem router's ASN)
   ├─ IP Address: "203.0.113.10" (your on-prem router's public IP)
   │  (This is the public IP of your firewall/VPN device)
   └─ Click: "Create customer gateway"

4. Result:
   └─ CGW created with your router's information
```

### Step 4: Create Site-to-Site VPN Connection

```
1. Go to: VPC → Site-to-Site VPN Connections
2. Click: "Create VPN connection"
3. Fill in:
   ├─ Name: "On-Prem-to-AWS-VPN"
   ├─ Target Gateway Type: "Virtual Private Gateway"
   ├─ Virtual Private Gateway: Select "Migration-VGW"
   ├─ Customer Gateway: Select "On-Prem-VMware-Router"
   ├─ Routing Options: ● "Dynamic" (uses BGP)
   ├─ Local IPv4 CIDR: "192.168.1.0/24" (on-prem network)
   ├─ Remote IPv4 CIDR: "10.0.0.0/16" (AWS VPC)
   ├─ DPD Timeout: "30" (seconds, for failover)
   └─ Click: "Create VPN connection"

4. Result:
   └─ VPN Connection created
   └─ Status: "pending" → "available"
```

### Step 5: Download VPN Configuration

```
1. Select your VPN Connection
2. Click: "Download configuration"
3. Choose your device:
   ├─ Cisco ASA
   ├─ Cisco IOS
   ├─ Palo Alto
   ├─ Fortinet FortiGate
   ├─ pfSense
   ├─ StrongSwan
   ├─ Generic
   └─ Select your router model

4. AWS generates configuration file with:
   ├─ Tunnel 1 details (IP, PSK, BGP config)
   ├─ Tunnel 2 details (backup)
   ├─ BGP neighbor information
   ├─ IPSec parameters
   └─ Device-specific commands

5. Download the file
   └─ You'll use this to configure your on-prem router
```

### Step 6: Enable VPN Propagation (AWS Route Table)

```
1. Go to: VPC → Route Tables
2. Select the route table attached to your subnet
3. Click: "Route propagation"
4. Enable: "Virtual Private Gateway"
   ├─ Check the VGW checkbox
   └─ Click: "Save"

5. Result:
   └─ Routes from on-prem automatically appear in route table
   └─ When on-prem advertises 192.168.1.0/24, it appears here
```

---

## Step-by-Step: Configure On-Premises Router

### Extract Key Information from AWS

From the downloaded configuration file:
```
Tunnel 1:
├─ Outside IP (AWS): 52.x.x.x
├─ Inside IP (AWS): 169.254.100.1
├─ Inside IP (Customer): 169.254.100.2
├─ Pre-Shared Key: xxxxxxxx
└─ BGP Details:
    ├─ AWS ASN: 64512
    └─ Inside IP: 169.254.100.1

Tunnel 2:
├─ Outside IP (AWS): 52.y.y.y
├─ Inside IP (AWS): 169.254.101.1
├─ Inside IP (Customer): 169.254.101.2
├─ Pre-Shared Key: yyyyyyyy
└─ BGP Details:
    ├─ AWS ASN: 64512
    └─ Inside IP: 169.254.101.1
```

### Configuration Steps (Cisco ASA Example)

```
On your Cisco Router, configure:

1. IPSec Phase 1 (Tunnel 1)
   crypto ikev1 enable outside
   crypto ikev1 policy 100
     encryption aes
     hash sha
     authentication pre-share
     group 2
     lifetime 28800

2. IPSec Phase 2
   crypto ipsec ikev1 transform-set TS esp-aes esp-sha-hmac
   crypto ipsec security-association lifetime seconds 3600

3. Tunnel 1 Configuration
   interface Tunnel1
     ip address 169.254.100.2 255.255.255.252
     tunnel source 203.0.113.10
     tunnel destination 52.x.x.x
     tunnel mode ipsec ipv4

4. BGP Configuration
   router bgp 65000
     bgp log-neighbor-changes
     neighbor 169.254.100.1 remote-as 64512
     !
     address-family ipv4
       neighbor 169.254.100.1 activate
       network 192.168.1.0 mask 255.255.255.0
       exit-address-family

5. Repeat for Tunnel 2 with different IPs
```

**Note:** The exact syntax depends on your router model. AWS provides device-specific configs in the downloaded file.

---

## Verify VPN Connection is Working

### In AWS Console

```
1. Go to: VPC → Site-to-Site VPN Connections
2. Select your VPN Connection
3. Check Tunnel Status:

   Tunnel 1:
   ├─ Status: ● UP (green)
   └─ BGP Status: ● UP (green)
   
   Tunnel 2:
   ├─ Status: ● UP (green)
   └─ BGP Status: ● UP (green)

4. Check Details:
   ├─ Data In: X GB (traffic from on-prem to AWS)
   ├─ Data Out: Y GB (traffic from AWS to on-prem)
   └─ Both should be > 0 if working
```

### From On-Premises Router (Cisco)

```
SSH into your router and run:

1. Check tunnel status:
   $ show crypto session brief
   Output:
   Crypto session current status
   Interface  : Tunnel1
   Status     : UP-ACTIVE
   Encr/Auth  : aes/sha

2. Check BGP session:
   $ show ip bgp summary
   Output:
   Neighbor        V    AS MsgRcvd MsgSent   TblVer InQ OutQ Up/Down State/PfxRcd
   169.254.100.1   4 64512     100      98       10   0    0 01:23:45 Established

   State should be "Established" (not "Active" or "Idle")

3. Check learned routes:
   $ show ip bgp
   Output:
   BGP routing table entry for 10.0.0.0/16, version 3
   Paths: (1 available, best #1, table Default-IP-Routing-Table)
   Flag: 0x820
     64512
       169.254.100.1 from 169.254.100.1 (52.x.x.x)
       
   This means: On-prem learned AWS VPC (10.0.0.0/16)

4. Test connectivity (ping AWS instance):
   $ ping 10.0.1.50 -c 4
   Output:
   Reply from 10.0.1.50: bytes=32 time=20ms TTL=63
   
   Successful ping = VPN working!
```

### From AWS Console (Route Table)

```
1. Go to: VPC → Route Tables
2. Select your route table
3. Look for propagated routes:
   
   Destination       Target              Status
   10.0.1.0/24       Local               Active
   192.168.1.0/24    VGW (vpn-xxxx)     Active
   
   The 192.168.1.0/24 route appeared via BGP propagation!
```

---

## VPN Fully Working! Now Install MGN

Once VPN is confirmed working:

```
On-Prem Network ←──VPN──→ AWS Network
  ✅ Connected via encrypted tunnel
  ✅ BGP routes exchanged
  ✅ Can ping between networks
  ✅ Ready for MGN migration!
```

---

## Step 1: Prepare AWS for MGN

### Create IAM Role for MGN

```
In AWS Console:

1. Go to: IAM → Roles
2. Click: "Create role"
3. Choose:
   ├─ Service: "EC2"
   └─ Click: "Next"

4. Add permissions:
   ├─ Search: "AWSApplicationMigrationMGN"
   ├─ Select: "AWSApplicationMigrationMGN"
   └─ Click: "Next"

5. Name the role:
   ├─ Name: "MGN-Migration-Role"
   └─ Click: "Create role"
```

### Create Replication Server (Optional Pre-Setup)

```
In AWS Console:

1. Go to: Application Migration Service
2. Click: "Get started"
3. Choose region: us-east-1
4. Create replication server:
   ├─ VPC: "On-Prem-Migration"
   ├─ Subnet: "Migration-Subnet"
   ├─ Security Group: Create new or select existing
   └─ Click: "Initialize"

This creates infrastructure where server data will replicate.
```

---

## Step 2: Install MGN Agent on Your VMware Server

### On Your On-Premises VMware Server

```
For Linux Server:

1. Download MGN agent:
   $ wget https://aws-application-migration-service.us-east-1.amazonaws.com/latest/linux/replication-agent-installer.tar.gz

2. Extract:
   $ tar -xzf replication-agent-installer.tar.gz
   $ cd replication-agent-*

3. Run installer:
   $ sudo ./install.sh \
     --region us-east-1 \
     --aws-access-key-id YOUR_ACCESS_KEY \
     --aws-secret-access-key YOUR_SECRET_KEY

   Or (recommended - using IAM role):
   $ sudo ./install.sh --region us-east-1

4. Verify installation:
   $ sudo systemctl status replication-agent
   Output:
   ● replication-agent.service - Loaded active running
   
   ✅ Agent running and replicating!
```

```
For Windows Server:

1. Download installer:
   https://aws-application-migration-service.us-east-1.amazonaws.com/latest/windows/replication-agent-installer.exe

2. Run as Administrator:
   Right-click → "Run as administrator"

3. Follow wizard:
   ├─ Region: us-east-1
   ├─ AWS Access Key ID: YOUR_ACCESS_KEY
   ├─ AWS Secret Key: YOUR_SECRET_KEY
   └─ Click: "Install"

4. Verify in Services:
   ├─ Win + R
   ├─ Type: services.msc
   ├─ Find: "AWS Replication Agent"
   ├─ Status: Running
   └─ ✅ Ready!
```

---

## Step 3: Monitor Replication Progress

### In AWS Console

```
1. Go to: Application Migration Service → Servers
2. You should see your server listed:
   
   Server Name: web-prod-01
   Status: ● Replicating
   Replication Progress: 45%
   Data Replicated: 225 GB / 500 GB
   Replication Lag: 2 seconds

3. Replication stages:
   ├─ 0-10%: Initial replication starting
   ├─ 10-50%: Bulk data transfer
   ├─ 50-90%: Finishing bulk transfer
   ├─ 90-100%: Final sync
   └─ 100%: Ready for test/cutover

4. Typical timeline:
   ├─ 500 GB: ~4 hours (on 100 Mbps link)
   ├─ 1 TB: ~8 hours
   ├─ 100 GB: ~1 hour
   └─ Depends on network bandwidth
```

---

## Step 4: Test Before Cutover

### Launch Test Instance

```
In AWS Console:

1. Go to: Application Migration Service → Servers
2. Select your server
3. Click: "Test and Cutover" → "Launch test instance"
4. Choose:
   ├─ Instance Type: c5.2xlarge (match on-prem specs)
   ├─ VPC: "On-Prem-Migration"
   ├─ Subnet: "Migration-Subnet"
   └─ Click: "Launch"

5. AWS creates temporary EC2 instance
   ├─ Status: Initializing → Launching → Running
   ├─ Time: ~5 minutes
   └─ Instance has your entire disk replicated
```

### Test the Instance

```
1. RDP/SSH into test instance:
   For Linux:
   $ ssh -i key.pem ubuntu@10.0.1.xxx
   
   For Windows:
   - Get password from console
   - RDP to: 10.0.1.xxx

2. Verify everything:
   
   ✓ OS is correct:
   $ uname -a  (Linux)
   $ ipconfig  (Windows)
   
   ✓ Applications running:
   $ ps aux | grep node
   $ systemctl status nginx
   
   ✓ Data present:
   $ ls -la /application/data
   $ du -sh /data/*
   
   ✓ Database accessible:
   $ psql -h localhost -d mydb -c "SELECT COUNT(*) FROM users"
   Output: 1000000 rows
   
   ✓ Network accessible:
   $ curl localhost
   $ curl 10.0.1.50  (ping other AWS resources)
   
   ✓ External connectivity:
   $ curl google.com

3. If all working:
   └─ ✅ Good to proceed with cutover

4. If issues found:
   ├─ Note the problem
   ├─ Terminate test instance
   ├─ Fix issue on on-prem server
   ├─ Wait for replication to sync (lag = 0)
   └─ Launch test again
```

### Terminate Test Instance

```
1. Click: "Terminate test instance"
2. Confirm: "Yes, terminate"
3. Instance is deleted
4. You're ready for actual cutover!
```

---

## Step 5: Perform Cutover (Migration!)

### Pre-Cutover Checklist (30 minutes before)

```
✓ VPN verified working (tunnels UP)
✓ Replication lag = 0 seconds
✓ Test instance passed all checks
✓ Database backups taken
✓ Team on standby
✓ Rollback plan ready
✓ Cutover window scheduled (Saturday 2 AM)
```

### Cutover Steps (15 minutes)

```
T - 10 min: Stop traffic to on-prem
            └─ No new requests accepted
            └─ Let existing connections complete

T - 5 min:  Verify replication lag = 0
            └─ AWS copy is identical to on-prem
            └─ All data transferred

T - 0 min:  Click "Finalize Cutover"
            In AWS Console:
            1. Go to: Application Migration Service → Servers
            2. Select your server
            3. Click: "Test and Cutover" → "Launch cutover instance"
            4. Choose same settings as test
               ├─ Instance Type: c5.2xlarge
               ├─ VPC: On-Prem-Migration
               ├─ Subnet: Migration-Subnet
               └─ Click: "Launch"
            
            AWS creates production EC2 instance:
            ├─ Status: Initializing → Running
            ├─ Time: ~5 minutes
            └─ This is your new production server!

T + 1 min:  Update DNS / Application Config
            Option 1: Update DNS
            └─ Change DNS record to point to new AWS IP
            
            Option 2: Update Application Config
            └─ Update connection strings to AWS IP
            
            Option 3: Update Load Balancer
            └─ Switch target from on-prem to AWS

T + 5 min:  Monitor
            ├─ Watch CloudWatch metrics
            ├─ Watch application logs
            ├─ Monitor CPU, memory, network
            ├─ Check for errors
            └─ Verify customers see service

T + 30 min: Verify Success
            ├─ Test application functionality
            ├─ Run test queries on database
            ├─ Check business critical paths
            ├─ Monitor error logs (should be zero)
            ├─ If OK → Migration successful! 🎉
            └─ If NOT → Rollback to on-prem

Result: Your VMware server now running in AWS!
```

---

## Post-Cutover: Keep On-Prem as Backup

### Days 1-3: Keep On-Prem Server Running

```
Reason:
├─ In case we need to rollback
├─ As backup in case AWS has issues
├─ Time to verify everything works

Monitoring:
├─ Watch AWS metrics (CPU, memory, network)
├─ Watch application logs
├─ Monitor database performance
├─ Check if users report issues
└─ If all good → AWS stable ✅

Backup Plan (Just in case):
├─ If AWS issues occur
├─ Switch traffic back to on-prem
├─ Investigate AWS issues
├─ Fix and try again
```

### Day 4+: Safe to Shut Down On-Prem

```
Once confident AWS is stable:

1. Ensure final backups from AWS taken
2. Archive on-prem data (if needed for compliance)
3. Shut down on-prem server:
   $ sudo shutdown -h now

4. Remove from VMware:
   ├─ Right-click → Remove from Inventory
   └─ (Don't delete VMDK files immediately, just in case)

5. Deallocate hardware:
   ├─ Return to IT
   ├─ Sell
   ├─ Recycle
   └─ Return rack space

6. Cost savings begin! 💰
```

---

## Complete Migration Timeline

```
Week 1: VPN Setup & Planning
├─ Create VGW, CGW, VPN Connection
├─ Configure on-prem router
├─ Verify VPN working
└─ Total: 16 hours

Week 2: MGN Preparation
├─ Create IAM roles
├─ Initialize MGN
├─ Plan replication
└─ Total: 8 hours

Week 3: Replication & Testing
├─ Install MGN agent (1 hour)
├─ Monitor replication (4-8 hours depending on data size)
├─ Launch test instance (30 min)
├─ Test thoroughly (2-4 hours)
└─ Total: 8-14 hours

Week 4: Cutover
├─ Execute cutover (15 minutes active time)
├─ Update DNS (5 min)
├─ Monitor (30 min)
├─ Verify success (30 min)
└─ Total: 1 hour active, 24 hours monitoring

Week 5: Validation & Cleanup
├─ Day 1-3: Keep on-prem backup
├─ Day 4+: Decommission on-prem
├─ Clean up resources
└─ Total: 8 hours

TOTAL: 4-5 weeks for complete migration
```

---

## Cost Analysis

### Before Migration (On-Premises)

```
Monthly Costs:
├─ Hardware (server): $2000
├─ Power & Cooling: $300
├─ Network: $200
├─ Storage: $500
├─ Maintenance: $200
└─ TOTAL: ~$3200/month
```

### After Migration (AWS)

```
Monthly Costs:
├─ EC2 (c5.2xlarge): $1200
├─ EBS (500 GB gp3): $150
├─ Data Transfer: $50
├─ VPN: $36 (hourly cost)
└─ TOTAL: ~$1436/month

Savings: $1764/month (55% reduction!)
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **VPN Tunnel Down** | Check on-prem firewall, verify PSK, check BGP session |
| **Replication Slow** | Check network bandwidth, move to AWS DataSync for large data |
| **Replication Lag High** | Increase network bandwidth, check on-prem server load |
| **Test Instance Won't Start** | Check security group allows RDP/SSH, verify EC2 role |
| **Application Won't Start** | Check OS differences, missing drivers, IP config |
| **Database Connection Fails** | Update connection strings, check security groups |
| **Performance Poor** | Right-size EC2 instance, check CPU/memory usage |

---

## Key Checklist: VPN + MGN Migration

```
✅ VPN Setup
   ✓ Created VGW
   ✓ Created CGW
   ✓ Created VPN Connection
   ✓ Downloaded config
   ✓ Configured on-prem router
   ✓ Verified tunnel UP
   ✓ Verified BGP Established

✅ MGN Preparation
   ✓ Created IAM role
   ✓ Initialized MGN
   ✓ Planned replication

✅ Replication
   ✓ Installed agent on on-prem server
   ✓ Replication running
   ✓ Monitoring progress
   ✓ Replication lag = 0

✅ Testing
   ✓ Launched test instance
   ✓ Verified OS
   ✓ Verified applications
   ✓ Verified data
   ✓ Verified network
   ✓ Terminated test instance

✅ Cutover
   ✓ Executed cutover
   ✓ Updated DNS
   ✓ Monitored AWS
   ✓ Verified success

✅ Post-Migration
   ✓ Kept on-prem 72 hours
   ✓ Decommissioned on-prem
   ✓ Claimed cost savings
```

---

## Summary

```
Your VMware Server Migration Flow:

1. Setup VPN Connection
   On-Prem ←──IPSec Encrypted──→ AWS
   
2. Install MGN Agent
   Agent starts replicating disk
   
3. Monitor Replication
   Disk copied to AWS EBS
   
4. Test Instance
   Launch test EC2 to verify
   
5. Cutover
   Switch traffic to AWS
   
6. Decommission
   Turn off on-prem server
   
7. Enjoy Cost Savings! 💰
```

**Your server is now in AWS, running live!**
