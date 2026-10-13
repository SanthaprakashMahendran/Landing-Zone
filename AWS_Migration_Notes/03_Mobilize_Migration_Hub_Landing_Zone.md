# Mobilize Phase: Migration Hub & Landing Zone (Control Tower)

---

## Table of Contents
1. What the Mobilize Phase Is For
2. Mobilize Checklist
3. AWS Migration Hub
4. What Is a Landing Zone?
5. AWS Organizations Basics
6. AWS Control Tower
7. Guardrails (Controls)
8. Account Factory (the "Account Vending Machine")
9. Account Factory for Terraform (AFT): What You Already Built
10. Landing Zone Design for Migrations
11. Assignment 1: Control Tower with 2 Accounts + Guardrails (Step by Step)
12. Common Problems
13. Key Takeaways

---

## 1. What the Mobilize Phase Is For

Assess told you **what** to move. Mobilize makes you **ready** to move it:

```
Mobilize deliverables
├─ A secure, governed AWS foundation      → Landing Zone (Control Tower)
├─ A tracked migration plan               → Migration Hub (apps, waves, status)
├─ Network connectivity to on-prem        → VPN / Direct Connect
├─ People who can run AWS                 → training + operating model
├─ Detailed portfolio and dependencies    → ADS data, strategy per app
└─ A working PILOT                        → proof that the whole process works
```

---

## 2. Mobilize Checklist

| Area | Item | Done? |
|---|---|---|
| **Foundation** | AWS Organization + management account | ☐ |
| | Control Tower landing zone with OUs, Log Archive and Audit accounts | ☐ |
| | Workload accounts (dev/test/prod) via Account Factory | ☐ |
| | Guardrails enabled on each OU | ☐ |
| | IAM Identity Center (SSO) configured | ☐ |
| **Network** | VPC design with non-overlapping CIDRs | ☐ |
| | Site-to-Site VPN or Direct Connect to on-prem | ☐ |
| | DNS plan (Route 53, on-prem forwarding) | ☐ |
| **Security** | Logging (CloudTrail, Config) centralized | ☐ |
| | Encryption and KMS key standards | ☐ |
| | Data classification and compliance mapping | ☐ |
| **Operations** | Monitoring/alerting standard, backup standard, patching approach | ☐ |
| | Cost management: budgets, tagging policy | ☐ |
| **Migration** | Applications grouped in Migration Hub | ☐ |
| | Waves planned, pilot chosen | ☐ |
| | MGN/DMS/DataSync prepared (IAM, templates) | ☐ |
| **People** | Training plan, roles and responsibilities defined | ☐ |

---

## 3. AWS Migration Hub

### What it is
A **single place to plan and track** a migration across multiple AWS tools and partner tools.

```
                      ┌───────────────── Migration Hub ─────────────────┐
 ADS (discovery) ───▶ │  Servers → grouped into APPLICATIONS             │
 MGN             ───▶ │  Status per app: Not started / In progress / Done│ ──▶ Dashboard
 DMS             ───▶ │  Strategy recommendations (6R)                   │
 Partner tools   ───▶ │  Waves, notes                                    │
                      └──────────────────────────────────────────────────┘
```

### Key concepts

| Concept | Meaning |
|---|---|
| **Home region** | The one region where Migration Hub stores data (choose once, early) |
| **Discovered servers** | Come from ADS (agent/agentless) or CSV import |
| **Application grouping** | Group servers into an app (for example "Customer Portal" = web + app + DB servers) |
| **Migration tracking** | MGN and DMS report job status to Hub, so you see progress per app |
| **Strategy Recommendations** | Suggests a 6R per server/app from discovery data (Hub feature) |
| **Import** | Upload CSV of servers/apps if you didn't use ADS |

### Typical flow

```
1. Select the home region
2. Get server data: ADS collector/agents, or import a CSV from your CMDB
3. Group servers into applications
4. (Optional) Get strategy recommendations
5. Start migrations with MGN/DMS; they auto-report to Hub
6. Watch progress on the dashboard
```

### Why it helps
- One status view for leadership (instead of 10 spreadsheets)
- Links **discovery → planning → migration tools**

> **Check current availability.** AWS adjusts its migration services over time, and some Migration Hub capabilities may change or be limited for new customers. Read the Migration Hub documentation before you rely on a specific feature, and keep your own wave tracker (spreadsheet or Jira) as a backup.

---

## 4. What Is a Landing Zone?

A **landing zone** is a **pre-built, secure, multi-account AWS foundation** that new workloads "land" in.

```
Without a landing zone:
   one AWS account, everything mixed together, no guardrails, hard to audit

With a landing zone:
   ┌────────────── AWS Organization ──────────────┐
   │ Management account                           │
   │ ├─ Security OU                               │
   │ │    ├─ Log Archive account (all logs)       │
   │ │    └─ Audit account (security tooling)     │
   │ ├─ Infrastructure OU  (shared network, DNS)  │
   │ ├─ Workloads - Prod OU                       │
   │ ├─ Workloads - NonProd OU                    │
   │ └─ Sandbox OU                                │
   │ + SCPs, central logging, SSO, baseline config│
   └──────────────────────────────────────────────┘
```

### Why multiple accounts?

| Reason | Benefit |
|---|---|
| **Blast radius** | A problem in one account doesn't reach others |
| **Security boundary** | IAM isolation by environment or team |
| **Cost allocation** | Bills split per account |
| **Limits** | Service quotas are per account |
| **Compliance** | Isolate regulated workloads |

---

## 5. AWS Organizations Basics

| Term | Meaning |
|---|---|
| **Organization** | The container for all accounts |
| **Management account** | Pays the bills and creates accounts. **Keep workloads out of it.** |
| **OU (Organizational Unit)** | A folder of accounts. Policies attach to OUs |
| **Member account** | Any other account |
| **SCP (Service Control Policy)** | A permission **ceiling** applied to an OU/account. It never grants permissions, it only limits them |

```
SCP example: "Deny any action outside ap-south-1 and us-east-1"
Even an administrator in a member account cannot use other regions.
```

---

## 6. AWS Control Tower

### What it is
A managed service that **sets up and governs a landing zone for you**, following AWS best practices.

### What it creates

| Item | Detail |
|---|---|
| **Landing zone** | Built on AWS Organizations, in a chosen **home region** |
| **OUs** | `Security` (with accounts `Log Archive` and `Audit`) and optionally `Sandbox`, plus ones you create |
| **Central logging** | CloudTrail + Config logs from every account into the Log Archive account (S3) |
| **IAM Identity Center** | SSO for people |
| **Guardrails (controls)** | Preventive and detective rules applied to OUs |
| **Account Factory** | Standard way to create new accounts |
| **Dashboard** | Compliance status of accounts/OUs |

### Concepts

| Concept | Meaning |
|---|---|
| **Home region** | Where Control Tower runs. It **cannot be changed** later |
| **Governed regions** | Regions where guardrails apply |
| **Enrolled account** | An account under Control Tower governance |
| **Drift** | Someone changed something outside Control Tower. The dashboard flags it so you can repair it |

---

## 7. Guardrails (Controls)

A **guardrail** is a high-level rule for governance.

### Types

| Type | Implemented by | Behavior | Example |
|---|---|---|---|
| **Preventive** | **SCP** | Blocks the action | "Disallow changes to CloudTrail", "Deny leaving the Organization" |
| **Detective** | **AWS Config rule** | Detects and reports non-compliance | "Detect unencrypted EBS volumes", "Detect public S3 buckets" |
| **Proactive** | **CloudFormation hooks** | Checks resources **before** deployment | "Require S3 bucket encryption in templates" |

### Behavior categories

| Category | Meaning |
|---|---|
| **Mandatory** | Always on and can't be disabled (protects the landing zone itself) |
| **Strongly recommended** | AWS best practice. You choose to enable |
| **Elective** | Optional, for specific needs |

### Applying guardrails
Guardrails are enabled **per OU**, and every account in that OU inherits them.

```
OU: Workloads-Prod
 ├─ Guardrail: Disallow public read access to S3 buckets        (preventive)
 ├─ Guardrail: Detect whether EBS volumes are unencrypted       (detective)
 └─ Guardrail: Deny actions outside approved regions            (preventive, region deny)
```

### Example effects

| Guardrail | If you try... | Result |
|---|---|---|
| Region deny (only ap-south-1) | Launching EC2 in eu-west-1 | **AccessDenied** (SCP) |
| Disallow public S3 | Making a bucket public | Blocked |
| Detect unencrypted EBS | Creating an unencrypted volume | Allowed, flagged **Non-compliant** on the dashboard |

---

## 8. Account Factory (the "Account Vending Machine")

**Account Factory** creates **new, pre-configured accounts** on demand, which is why it's called the **account vending machine**.

```
Request ─▶ Account Factory (Service Catalog product) ─▶ New account
                                                           ├─ placed in the chosen OU
                                                           ├─ guardrails inherited
                                                           ├─ logging enabled
                                                           ├─ baseline VPC (optional)
                                                           └─ SSO access configured
```

### What you provide

| Field | Notes |
|---|---|
| **Account email** | **Unique**, never used for another AWS account (use `name+tag@domain` aliases if your provider supports it) |
| **Account name** | For example `workload-dev-01` |
| **IAM Identity Center user** | The user who gets access (email and name) |
| **OU** | Where the account lands |

### Customization options
- **Account Factory customization (AFC)**, **Customizations for Control Tower (CfCT)**, and **AFT** all add a standard baseline to every new account (VPC, security tools, budgets, tags).

---

## 9. Account Factory for Terraform (AFT): What You Already Built

Your repo already uses **AFT** (see [README.md](../README.md) and [DEPLOYMENT-CHECKLIST.md](../DEPLOYMENT-CHECKLIST.md)):

```
Terraform request (Git) ─▶ AFT pipeline ─▶ Account Factory ─▶ new account
                                         └─▶ account-specific customizations (Terraform)
```

| Console Account Factory | AFT |
|---|---|
| Manual form in the console | **Code-driven** (account requests as Terraform files in Git) |
| Good for a few accounts | Good for many accounts, with an audit trail |
| Customizations via Service Catalog/CfCT | Customizations as Terraform modules |
| Great to learn | Great for production |

**Learning order:** do **Assignment 1** manually (console) so you understand what AFT automates.

---

## 10. Landing Zone Design for Migrations

### Suggested OU/account layout

```
Root
├─ Management account              (billing, Organizations, Control Tower only)
├─ Security OU
│   ├─ Log Archive                 (central logs)
│   └─ Audit                       (security tooling, read-only access)
├─ Infrastructure OU
│   ├─ Network                     (Transit Gateway, VPN/Direct Connect, DNS, firewall)
│   └─ Shared Services             (AD, patching, monitoring)
├─ Workloads-NonProd OU
│   └─ App-A-dev, App-A-test ...
├─ Workloads-Prod OU
│   └─ App-A-prod ...
├─ Migration OU  (temporary)       ← holds MGN staging resources and migration tooling
└─ Sandbox OU                      (experiments, with budget limits)
```

### Network for hybrid migration

```
On-prem ──VPN / Direct Connect──▶ Network account (Transit Gateway)
                                         ├──▶ App-A-dev VPC
                                         ├──▶ App-A-prod VPC
                                         └──▶ Migration VPC (MGN staging area)
```

(The VPN steps are in `VPN_Setup_and_MGN_Migration.md`.)

### Baseline for every migration account

| Item | Standard |
|---|---|
| Tagging | `Environment`, `Owner`, `CostCenter`, `Application`, and `map-migrated` if in MAP |
| Budgets | Alert at 80% of monthly budget |
| Logging | CloudTrail, Config, VPC Flow Logs → Log Archive |
| Encryption | EBS encryption by default, KMS keys per environment |
| Access | IAM Identity Center groups mapped to permission sets (see `AWS_IAM_SSO_Notes.md`) |
| Guardrails | Region restriction, no public S3, CloudTrail protection, unencrypted volume detection |

---

## 11. Assignment 1: Control Tower with 2 Accounts + Guardrails (Step by Step)

**Goal:** Create **2 accounts** through Account Factory and **apply guardrails** to their OU.

> Your repo notes say Control Tower is **already enabled** with a landing zone in `us-east-1`. If it isn't, enable it first: **Control Tower → Set up landing zone**, choose the home region, and let it create the `Security` OU plus the `Log Archive` and `Audit` accounts. This takes ~30–60 minutes.

### Preconditions
- Logged into the **management account** as a user with administrator access
- **2 unique email addresses** not used by any AWS account (for example `you+ct-dev@gmail.com` and `you+ct-test@gmail.com`; Gmail `+` aliases work)
- IAM Identity Center is enabled

### Step 1: Create an OU

```
Control Tower → Organization → Create resources → Create organizational unit
Name: Workloads-Sandbox
Parent: Root
```

### Step 2: Create account #1 with Account Factory

```
Control Tower → Account Factory → Create account
  Account email:        you+ct-dev@gmail.com
  Display name:         ct-dev-01
  IAM Identity Center user email: you@gmail.com
  Name/surname:         (your name)
  Organizational unit:  Workloads-Sandbox
→ Create account   (takes ~15–30 minutes; status: "In progress" → "Enrolled")
```

### Step 3: Create account #2
Repeat with `you+ct-test@gmail.com`, `ct-test-01`, same OU.

### Step 4: Enable guardrails (controls) on the OU

```
Control Tower → Controls library (or "Guardrails") → pick a control → Enable control on OU
Enable on OU "Workloads-Sandbox":
  1. Disallow public read access to Amazon S3 buckets            (preventive)
  2. Detect whether encryption is enabled for Amazon EBS volumes (detective)
  3. Region deny (Control Tower → Landing zone settings → Region deny)
```

Wait for the control status to show **Enabled**, and for the OU/accounts to show compliant.

### Step 5: Verify

| Test | Expected |
|---|---|
| Log in to `ct-dev-01` through the **IAM Identity Center portal** | Works with SSO, no password for the root user needed |
| Try to create a **public S3 bucket** in `ct-dev-01` | Blocked by the preventive control |
| Create an **unencrypted EBS volume** | Allowed, then shows **Non-compliant** under *Control Tower → Dashboard / Noncompliant resources* (detective) |
| Try creating a resource in a **denied region** | `AccessDenied` |
| Check **Log Archive account → S3** | CloudTrail logs from the new accounts are arriving |
| Control Tower dashboard | Accounts show **Enrolled**, no drift |

### Step 6: Take notes (this is the real deliverable)
- What each guardrail did
- Time taken to create an account
- What the SCP/Config rule looked like (**Organizations → Policies → SCPs**, **Config → Rules** in the member account)

### Step 7: Clean up (important)

```
1. Delete all resources you created in the 2 accounts
2. Control Tower → Account Factory → Accounts → select account → Unmanage/Terminate account
   (this closes the account; AWS allows limited account closures in a time window)
3. Delete the OU if empty
```

> **Cost:** accounts are free if empty, but Control Tower's baseline services (Config, CloudTrail, S3 logs) have small ongoing charges. Don't leave experiments running.

---

## 12. Common Problems

| Problem | Cause | Fix |
|---|---|---|
| "Email already in use" | The email was used for another AWS account | Use a new alias or address |
| Account stuck "In progress" | Service Catalog/provisioning problem | Check *Service Catalog provisioned products* and CloudFormation events |
| Guardrail "Enable" fails | OU not enrolled, or a region mismatch | Re-register the OU, and check governed regions |
| Resource blocked unexpectedly | A preventive SCP | Read the error message, and check **Organizations → SCPs** |
| Drift detected | Someone changed a Control Tower-managed resource | **Re-register OU / repair** in the Control Tower console |
| Can't log in to the new account | Identity Center user not assigned | Assign the user/permission set to the account |
| Home region wrong | Chosen at setup, can't change | Decommission and rebuild (so choose carefully) |

---

## 13. Key Takeaways

```
1. Mobilize = foundation + plan + people + pilot. It must finish before big migration waves.
2. Migration Hub = one place to group servers into applications and track migration status.
3. Landing zone = multi-account, secure, governed foundation (OUs, central logs, SSO, guardrails).
4. Control Tower builds and governs it. Home region is permanent.
5. Guardrails: Preventive (SCP) blocks, Detective (Config) reports, Proactive (CloudFormation hooks) checks before deploy.
6. Account Factory = account vending machine. AFT = the same, driven by Terraform (what your repo does).
7. Keep workloads out of the management account. Use separate prod/non-prod and a temporary Migration OU.
8. Practice by creating 2 accounts, enabling guardrails, breaking the rules on purpose, then cleaning up.
```

**Next note:** `04_AWS_MGN_Deep_Dive.md`
