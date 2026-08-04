# AWS IAM Identity Center + Azure AD SSO Setup Notes

## Overview

AWS IAM Identity Center connects your Azure AD identity to AWS, allowing users to log in with their Freshworks email (e.g., `smahendran@freshworks.com`) and access multiple AWS accounts with appropriate permissions.

---

## Your Setup

**User:** smahendran@freshworks.com (Azure AD)
**Accounts:** 6 total (3 prod + 3 staging)
**Groups:** 
- product_team_group (P1, P2, P3) → Admin access to all 6 accounts
- support_team_group (S1, S2) → Write access to 3 staging only

---

## Key Concept: Management Account is Central Hub

```
AWS Organization
│
├── Management Account (Setup happens HERE)
│   └── IAM Identity Center + Azure AD connected ✅ (Done once)
│
├── Prod Account 1 ⬅️ Automatically gets SSO
├── Prod Account 2 ⬅️ Automatically gets SSO
├── Prod Account 3 ⬅️ Automatically gets SSO
├── Staging Account 1 ⬅️ Automatically gets SSO
├── Staging Account 2 ⬅️ Automatically gets SSO
└── Staging Account 3 ⬅️ Automatically gets SSO
```

**Important:** You only set up in the Management Account. All child accounts automatically inherit SSO.

---

## Step-by-Step Setup

### Step 1: Connect Azure AD to AWS (Management Account Only)

#### In AWS Management Account:

1. Go to **IAM Identity Center** → **Settings**
2. Choose identity source: **"External identity provider"** → **SAML 2.0**
3. AWS generates metadata XML (download it)
4. Note the following:
   - SAML metadata document (XML file)
   - Sign-in URL
   - Sign-out URL

#### In Azure AD Admin Portal:

1. Go to **Azure AD** → **Enterprise applications**
2. Click **"New application"** → **"Create your own application"**
3. Name: `AWS IAM Identity Center`
4. Select: **"Integrate any other application you don't find in the gallery"**
5. Go to **Single sign-on** → **SAML**
6. **Upload AWS metadata XML** (from Step 3 above)
7. Configure SAML Claim Mappings:
   ```
   Email:     user.mail
   Groups:    user.groups
   FirstName: user.givenName
   LastName:  user.surname
   ```
8. Download Azure AD metadata XML
9. Go back to AWS IAM Identity Center → paste Azure AD metadata XML

**Result:** Azure AD ↔ AWS IAM Identity Center connection established ✅

---

### Step 2: Users and Groups Auto-Sync

Once Azure AD is connected:

**Auto-synced Users:**
- smahendran@freshworks.com
- P1@freshworks.com
- P2@freshworks.com
- P3@freshworks.com
- S1@freshworks.com
- S2@freshworks.com

**Auto-synced Groups:**
- product_team_group (contains P1, P2, P3)
- support_team_group (contains S1, S2)

*You don't manually create users — Azure AD syncs them automatically.*

---

### Step 3: Create Permission Sets (in Management Account)

Permission Sets are reusable templates that define permissions.

#### Permission Set 1: ProductTeamAdmin

**Name:** ProductTeamAdmin
**Description:** Full admin access

**Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

#### Permission Set 2: SupportTeamWrite

**Name:** SupportTeamWrite
**Description:** Write access to resources, no IAM

**Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "s3:*",
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "organizations:*",
        "account:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

### Step 4: Assign Groups to AWS Accounts (in Management Account)

**Where:** AWS IAM Identity Center → AWS Accounts

**For each AWS account, click "Assign users or groups"**

#### Assignment 1: product_team_group

- **Group:** product_team_group
- **Permission Set:** ProductTeamAdmin
- **Assign to:** All 6 accounts (Prod 1, 2, 3 + Staging 1, 2, 3)

#### Assignment 2: support_team_group

- **Group:** support_team_group
- **Permission Set:** SupportTeamWrite
- **Assign to:** Only 3 staging accounts (NOT prod)

---

## Where Permissions Are Assigned

| Component | Created In | Assigned In |
|-----------|-----------|-----------|
| **Users** | Azure AD | ❌ (synced automatically) |
| **Groups** | Azure AD | ❌ (synced automatically) |
| **Permission Sets** | AWS IAM Identity Center | ✅ |
| **Assignments** (group → permission set → accounts) | — | ✅ AWS IAM Identity Center |

**Assignments happen in:** AWS IAM Identity Center → AWS Accounts → [Select Account] → "Assign users or groups"

**Steps:**
1. Go to AWS Accounts section
2. Click account (Prod 1, Prod 2, etc.)
3. Click "Assign users or groups"
4. Select group (product_team_group or support_team_group)
5. Select permission set (ProductTeamAdmin or SupportTeamWrite)
6. Click Assign
7. Repeat for all relevant accounts

---

## User Login Flows

### Your Login (smahendran@freshworks.com)

**Step 1:** Navigate to AWS SSO Portal
```
URL: https://ACCOUNT-ID.awsapps.com/start
```

**Step 2:** See Azure AD login screen
```
Login with Azure AD
├── Email: smahendran@freshworks.com
├── Password: (your Freshworks password)
└── MFA: (if enabled)
```

**Step 3:** Azure AD verifies you
```
Azure AD checks:
├── Email valid ✓
├── Password correct ✓
├── Member of product_team_group ✓
└── Sends token to AWS
```

**Step 4:** AWS grants access
```
AWS SSO Portal:
├── Prod Account 1 (Admin Access) — Click to access
├── Prod Account 2 (Admin Access) — Click to access
├── Prod Account 3 (Admin Access) — Click to access
├── Staging Account 1 (Admin Access) — Click to access
├── Staging Account 2 (Admin Access) — Click to access
└── Staging Account 3 (Admin Access) — Click to access
```

**Step 5:** Click any account
```
→ AWS generates temporary credentials (1 hour valid)
→ Logs you into AWS Console
→ Full admin access
```

### Support Team Login (S1@freshworks.com)

**Step 1-3:** Same as above (Azure AD verification)

**Step 4:** AWS grants limited access
```
AWS SSO Portal:
├── Staging Account 1 (Write Access) ✓
├── Staging Account 2 (Write Access) ✓
├── Staging Account 3 (Write Access) ✓
└── (Prod accounts NOT visible)
```

**Step 5:** Click staging account
```
→ Gets temporary credentials
→ Can read/write to EC2, RDS, S3
→ Cannot modify IAM, cannot access prod
```

---

## Important Notes

| Question | Answer |
|----------|--------|
| Do I set up IAM Identity Center in each account? | ❌ NO — Only in Management Account |
| Do I connect Azure AD 6 times? | ❌ NO — Only once in Management Account |
| Do I create permission sets 6 times? | ❌ NO — Create once, apply to multiple accounts |
| Do child accounts need IAM roles? | ❌ NO — IAM Identity Center handles it automatically |
| Can users from child accounts log in? | ✅ YES — All users sync from Azure AD |
| Can I assign different groups to different accounts? | ✅ YES — Done in Management Account |
| What if I add a new AWS account to the org? | ✅ It automatically gets SSO access |
| Can I change permissions later? | ✅ YES — Edit permission sets or group assignments |

---

## Benefits Over Manual IAM Setup

| Aspect | Before (Manual IAM) | After (IAM Identity Center) |
|--------|---------------------|----------------------------|
| **Setup complexity** | High (per account) | Low (once in management) |
| **User management** | Manual creation in each account | Auto-sync from Azure AD |
| **Permission management** | Replicate IAM roles 6x | One permission set, apply to all |
| **Restricting access** | Hard to enforce (S1 might have prod) | Easy (don't assign prod to S1's group) |
| **User portal** | Must use AWS console directly | Clean SSO portal showing only accessible accounts |
| **Onboarding new user** | Add to 6 IAM accounts manually | Add to Azure AD group, auto-synced |
| **Removing user access** | Remove from 6 IAM roles manually | Remove from Azure AD group, instant |

---

## Complete Setup Checklist

```
✅ Step 1: Enable IAM Identity Center in Management Account
   └─ Settings → Identity source → External identity provider

✅ Step 2: Connect Azure AD
   └─ Download AWS metadata XML
   └─ In Azure AD: Add enterprise app, upload metadata
   └─ Configure SAML claim mappings
   └─ Upload Azure AD metadata back to AWS

✅ Step 3: Verify Users/Groups Auto-Synced
   └─ Check IAM Identity Center → Users section
   └─ Verify: smahendran@freshworks.com, P1, P2, P3, S1, S2 present
   └─ Check IAM Identity Center → Groups section
   └─ Verify: product_team_group, support_team_group present

✅ Step 4: Create Permission Sets
   └─ Create: ProductTeamAdmin (full admin)
   └─ Create: SupportTeamWrite (write-only)

✅ Step 5: Assign Groups to Accounts
   └─ product_team_group + ProductTeamAdmin → All 6 accounts
   └─ support_team_group + SupportTeamWrite → 3 staging only

✅ Step 6: Test User Login
   └─ Have smahendran@freshworks.com test login
   └─ Should see all 6 accounts
   └─ Have S1@freshworks.com test login
   └─ Should see only 3 staging accounts
```

---

## After Setup: Day-to-Day Operations

### Adding a New User

1. **In Azure AD:**
   - Create new user (e.g., `newuser@freshworks.com`)
   - Add to product_team_group or support_team_group
   
2. **In AWS:**
   - Nothing! User auto-syncs and gets access based on group

3. **User can immediately:**
   - Log in to AWS SSO portal
   - Access assigned accounts
   - No manual AWS setup needed

### Removing User Access

1. **In Azure AD:**
   - Remove from product_team_group or support_team_group
   
2. **In AWS:**
   - Nothing! Access revoked automatically

### Changing Permissions

1. **Edit Permission Set (all accounts affected):**
   - IAM Identity Center → Permission Sets
   - Edit ProductTeamAdmin policy
   - Changes apply to all 6 accounts instantly

2. **Change which accounts a group accesses:**
   - IAM Identity Center → AWS Accounts
   - Edit assignment
   - Remove from prod accounts
   - Now group only accesses staging

---

## Architecture Diagram

```
User Authentication Flow:
┌──────────────────────┐
│  smahendran@         │
│  freshworks.com      │
└──────────┬───────────┘
           │
           │ 1. Login request
           ▼
┌──────────────────────┐
│   Azure AD           │
│   (Identity Store)   │
│                      │
│ Groups:              │
│ - product_team_group │
│ - support_team_group │
└──────────┬───────────┘
           │
           │ 2. SAML token
           │    (user + groups)
           ▼
┌──────────────────────────────────────────┐
│  AWS IAM Identity Center                 │
│  (Management Account)                    │
│                                          │
│  Permission Sets:                        │
│  - ProductTeamAdmin                      │
│  - SupportTeamWrite                      │
│                                          │
│  Assignments:                            │
│  - product_team_group → ProductTeamAdmin │
│    → All 6 accounts                      │
│  - support_team_group → SupportTeamWrite │
│    → 3 staging accounts only             │
└──────────┬───────────────────────────────┘
           │
           │ 3. Temporary credentials + permissions
           ▼
┌──────────────────────────────────────────┐
│  Child AWS Accounts (Auto-inherit SSO)   │
│                                          │
│  ├── Prod Account 1 (Admin)              │
│  ├── Prod Account 2 (Admin)              │
│  ├── Prod Account 3 (Admin)              │
│  ├── Staging Account 1 (Write)           │
│  ├── Staging Account 2 (Write)           │
│  └── Staging Account 3 (Write)           │
└──────────────────────────────────────────┘
           │
           │ 4. Access granted
           ▼
    ┌──────────────┐
    │  AWS Console │
    │  (as user)   │
    └──────────────┘
```

---

## Quick Reference: Commands (CLI)

```bash
# List all permission sets
aws sso-admin list-permission-sets --instance-arn <arn> --region us-east-1

# List all accounts
aws organizations list-accounts

# List group assignments
aws sso-admin list-account-assignments \
  --instance-arn <arn> \
  --account-id <account-id> \
  --region us-east-1
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Users not appearing in IAM Identity Center | Check Azure AD sync is enabled, wait 15-30 mins |
| User can't see certain accounts | Check group assignment — may not be assigned |
| User sees account but can't access | Check permission set policy — may be too restrictive |
| Support team can access prod | Check group assignment — support_team_group should only be assigned to staging accounts |
| Changes not reflecting immediately | Wait 2-5 minutes for IAM propagation |

---

---

# Scenario 2: AWS-Only SSO (No Azure AD)

Everything created in AWS. Local users only.

## Key Difference

| Component | Scenario 1 (Azure AD) | Scenario 2 (AWS-Only) |
|-----------|-----|-----|
| Users created in | Azure AD | AWS |
| Groups created in | Azure AD | AWS |
| Login credentials | Azure AD password | AWS password |
| SSO to other apps | ✅ Slack, GitHub, Jira | ❌ AWS only |
| Best for | Enterprise | AWS-focused only |

## Step-by-Step Setup

### Step 1: Enable IAM Identity Center

1. Go to IAM Identity Center → Settings
2. Choose identity source: **"Local identity store"** (not external)
3. Click Enable

### Step 2: Create Users (in AWS)

Go to IAM Identity Center → Users:
- Click "Add user"
- Create: smahendran, P1, P2, P3, S1, S2
- Set AWS password for each

### Step 3: Create Groups (in AWS)

Go to IAM Identity Center → Groups:
- Create: product_team_group (add P1, P2, P3)
- Create: support_team_group (add S1, S2)

### Step 4: Create Permission Sets (in AWS)

Same as Scenario 1:
- ProductTeamAdmin (full admin)
- SupportTeamWrite (write only)

### Step 5: Assign Groups to Accounts

Same as Scenario 1:
- product_team_group + ProductTeamAdmin → All 6 accounts
- support_team_group + SupportTeamWrite → 3 staging only

## Login Flow (AWS-Only)

1. Navigate to: `https://ACCOUNT-ID.awsapps.com/start`
2. See AWS login (not Azure AD)
3. Enter: username (smahendran) + AWS password
4. Portal shows assigned accounts
5. Click account → access AWS

## When to Use Scenario 2

✅ Use AWS-Only:
- Only tool is AWS (no Slack, GitHub, Jira)
- Simple setup needed
- Small team
- Lab or testing environment

❌ Don't use AWS-Only:
- Need SSO to multiple apps
- Enterprise with centralized identity
- Large team
- Need audit compliance across apps

## Comparison Summary

```
Scenario 1 (Azure AD):          Scenario 2 (AWS-Only):
├─ Users in: Azure AD           ├─ Users in: AWS
├─ Groups in: Azure AD          ├─ Groups in: AWS
├─ Login: Azure AD password     ├─ Login: AWS password
├─ SSO to: All apps ✅          ├─ SSO to: AWS only ❌
└─ Best for: Enterprise         └─ Best for: AWS-only
```

---

## Summary

**Created In:**
- Scenario 1: Users & Groups → Azure AD | Permission Sets → AWS
- Scenario 2: Users & Groups → AWS | Permission Sets → AWS

**Assigned In:**
- Both: Group + Permission Set + Accounts → AWS IAM Identity Center

**Choose based on:**
- Multiple apps? → Scenario 1 (Azure AD)
- AWS only? → Scenario 2 (AWS-only)
