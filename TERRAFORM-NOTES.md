# 🔧 Terraform AFT - Quick Reference & Recall Guide

## 📖 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [main.tf Explained](#maintf-explained)
4. [outputs.tf Explained](#outputstf-explained)
5. [Key Concepts](#key-concepts)
6. [How It All Works](#how-it-all-works)
7. [Data Flow](#data-flow)

---

## 🏗️ Architecture Overview

**What does this Terraform code do?**
- Creates AWS Organizations structure with OUs (Organizational Units)
- Provisions multiple AWS accounts automatically
- Organizes accounts into Production and Staging environments
- Manages everything from a Management Account

```
Management Account (Control Tower)
    ↓
    ├─ Production OU
    │   ├─ freshdesk-prod (Account)
    │   ├─ freshservice-prod (Account)
    │   └─ freshsales-prod (Account)
    │
    └─ Staging OU
        ├─ freshdesk-staging (Account)
        ├─ freshservice-staging (Account)
        └─ freshsales-staging (Account)
```

---

## 📁 File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Creates OUs and AWS accounts, handles organization |
| `outputs.tf` | Exports account IDs, OUs, and mappings for reference |
| `variables.tf` | Defines inputs (accounts config, AWS region) |
| `versions.tf` | Specifies Terraform and provider versions |
| `terraform.tfvars` | Actual values for variables |
| `backend.tf.example` | Example state file backend config |

---

## 🔍 main.tf Explained

### **Section 1: Fetch Root OU** (Lines 1-4)
```hcl
data "aws_organizations_organization" "root" {
  provider = aws.management
}
```
**What it does:**
- Reads existing AWS Organizations structure
- Gets the Root OU ID to use as parent for new OUs
- `data` = read-only (doesn't create anything)
- `provider = aws.management` = uses Management Account credentials

**Why:** OUs need a parent ID. We fetch the root to attach new OUs to it.

---

### **Section 2: Create Production OU** (Lines 6-17)
```hcl
resource "aws_organizations_organizational_unit" "production" {
  provider  = aws.management
  name      = "Production"
  parent_id = data.aws_organizations_organization.root.roots[0].id
  
  tags = {
    Name        = "Production"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```
**What it does:**
- Creates a new OU called "Production"
- Attaches it to the root (`parent_id`)
- Adds tags for organization (Name, Environment, ManagedBy)

**Key:** `roots[0].id` = the Root OU ID from the data source above

---

### **Section 3: Create Staging OU** (Lines 19-30)
```hcl
resource "aws_organizations_organizational_unit" "staging" {
  provider  = aws.management
  name      = "Staging"
  parent_id = data.aws_organizations_organization.root.roots[0].id
  
  tags = {
    Name        = "Staging"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}
```
**Same as Production OU, but for Staging environment**

---

### **Section 4: Create AWS Accounts** (Lines 32-58)
```hcl
resource "aws_organizations_account" "accounts" {
  for_each = var.accounts  # ← Loop through account map
  
  provider = aws.management
  
  name              = each.key  # freshdesk-prod, freshservice-prod, etc.
  email             = each.value.email  # aws+freshdesk-prod@freshworks.com
  iam_user_access_to_billing = "ALLOW"  # Allow root access to billing
  close_on_deletion = false  # Don't delete account if Terraform destroys
  
  tags = {
    Name        = each.key
    Project     = each.value.project  # freshdesk, freshservice, freshsales
    Environment = each.value.environment  # prod or staging
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    ignore_changes = [email]  # Don't change email if it's updated manually
  }
  
  depends_on = [
    aws_organizations_organizational_unit.production,
    aws_organizations_organizational_unit.staging
  ]
}
```

**Key Concepts:**

| Concept | Explanation |
|---------|-------------|
| `for_each = var.accounts` | Loop through each account in the accounts map |
| `each.key` | Account name (e.g., "freshdesk-prod") |
| `each.value` | Account properties (email, project, environment) |
| `lifecycle { ignore_changes }` | Don't overwrite if manually changed |
| `depends_on` | Wait for OUs to be created first |

**How `for_each` works:**
```
var.accounts = {
  "freshdesk-prod" = { email: "aws+freshdesk-prod@freshworks.com", ... }
  "freshservice-prod" = { email: "aws+freshservice-prod@freshworks.com", ... }
  ...
}

Terraform creates:
- aws_organizations_account.accounts["freshdesk-prod"]
- aws_organizations_account.accounts["freshservice-prod"]
- aws_organizations_account.accounts["freshdesk-staging"]
- ... (6 total)
```

---

### **Section 5: Move Production Accounts to Production OU** (Lines 60-72)
```hcl
resource "aws_organizations_organizational_unit_parent" "prod_accounts" {
  for_each = {
    for name, account in var.accounts : name => account
    if account.environment == "prod"  # ← Only prod accounts
  }
  
  provider          = aws.management
  account_id        = aws_organizations_account.accounts[each.key].id
  parent_id         = aws_organizations_organizational_unit.production.id
  
  depends_on = [aws_organizations_account.accounts]
}
```

**What it does:**
- Filters accounts where `environment == "prod"`
- Moves each prod account under Production OU
- Links account ID to Production OU ID

**Filter Logic:**
```
for_each filters only these:
✅ freshdesk-prod (environment: prod)
✅ freshservice-prod (environment: prod)
✅ freshsales-prod (environment: prod)

❌ freshdesk-staging (environment: staging - excluded)
```

---

### **Section 6: Move Staging Accounts to Staging OU** (Lines 74-86)
```hcl
resource "aws_organizations_organizational_unit_parent" "staging_accounts" {
  for_each = {
    for name, account in var.accounts : name => account
    if account.environment == "staging"  # ← Only staging accounts
  }
  
  provider          = aws.management
  account_id        = aws_organizations_account.accounts[each.key].id
  parent_id         = aws_organizations_organizational_unit.staging.id
  
  depends_on = [aws_organizations_account.accounts]
}
```

**Same as prod, but for staging accounts**

---

## 📤 outputs.tf Explained

### **Output 1: Production OU ID**
```hcl
output "production_ou_id" {
  description = "Production Organizational Unit ID"
  value       = aws_organizations_organizational_unit.production.id
}
```
**Returns:** `ou-1234-abcd5678`

---

### **Output 2: Staging OU ID**
```hcl
output "staging_ou_id" {
  description = "Staging Organizational Unit ID"
  value       = aws_organizations_organizational_unit.staging.id
}
```
**Returns:** `ou-1234-efgh9012`

---

### **Output 3: Created Accounts (Full Details)**
```hcl
output "created_accounts" {
  description = "Created AWS accounts with their details"
  value = {
    for name, account in aws_organizations_account.accounts : name => {
      id          = account.id
      arn         = account.arn
      email       = account.email
      status      = account.status
      environment = var.accounts[name].environment
      project     = var.accounts[name].project
    }
  }
}
```

**Returns:**
```json
{
  "freshdesk-prod" = {
    "id" = "123456789012"
    "arn" = "arn:aws:organizations::123456789012:account/.../123456789012"
    "email" = "aws+freshdesk-prod@freshworks.com"
    "status" = "ACTIVE"
    "environment" = "prod"
    "project" = "freshdesk"
  }
  "freshdesk-staging" = { ... }
  ...
}
```

---

### **Output 4: Account ID to Name Mapping**
```hcl
output "account_mapping" {
  description = "Account ID to Name mapping"
  value = {
    for name, account in aws_organizations_account.accounts : account.id => name
  }
}
```

**Returns:**
```json
{
  "123456789012" = "freshdesk-prod"
  "210987654321" = "freshdesk-staging"
  "345678901234" = "freshservice-prod"
  ...
}
```

**Use case:** Given an account ID, quickly find its name

---

### **Output 5: Production Accounts Only**
```hcl
output "production_accounts" {
  description = "Production environment accounts"
  value = {
    for name, account in aws_organizations_account.accounts :
    name => account.id
    if var.accounts[name].environment == "prod"
  }
}
```

**Returns (prod accounts only):**
```json
{
  "freshdesk-prod" = "123456789012"
  "freshservice-prod" = "345678901234"
  "freshsales-prod" = "567890123456"
}
```

---

### **Output 6: Staging Accounts Only**
```hcl
output "staging_accounts" {
  description = "Staging environment accounts"
  value = {
    for name, account in aws_organizations_account.accounts :
    name => account.id
    if var.accounts[name].environment == "staging"
  }
}
```

**Returns (staging accounts only):**
```json
{
  "freshdesk-staging" = "210987654321"
  "freshservice-staging" = "432109876543"
  "freshsales-staging" = "654321098765"
}
```

---

## 💡 Key Concepts

### **1. for_each Loop**
```hcl
for_each = var.accounts
```
- Loops through each account in the map
- Creates a resource for EACH account
- Same as a forEach in programming

**Example:**
```
var.accounts = {
  "freshdesk-prod" = { ... }
  "freshdesk-staging" = { ... }
}

Creates:
aws_organizations_account.accounts["freshdesk-prod"]
aws_organizations_account.accounts["freshdesk-staging"]
```

---

### **2. Conditional Filtering (for_each with if)**
```hcl
for_each = {
  for name, account in var.accounts : name => account
  if account.environment == "prod"
}
```
- Loops through accounts
- ONLY includes if environment == "prod"
- Filters out all staging accounts

---

### **3. Data Source (Read-Only)**
```hcl
data "aws_organizations_organization" "root" {
  provider = aws.management
}
```
- Reads existing AWS resources
- Doesn't create anything
- Used to get information (Root OU ID)

---

### **4. Provider Specification**
```hcl
provider = aws.management
```
- Uses "management" AWS provider alias
- Must be configured in versions.tf
- Ensures we always run in Management Account

---

### **5. Dependencies (depends_on)**
```hcl
depends_on = [
  aws_organizations_organizational_unit.production,
  aws_organizations_organizational_unit.staging
]
```
- Wait for OUs to be created first
- Then create accounts
- Prevents ordering issues

---

### **6. Lifecycle Rules**
```hcl
lifecycle {
  ignore_changes = [email]
}
```
- Don't overwrite email if changed manually
- Terraform won't revert manual email changes
- Useful for sensitive fields

---

## 🔄 How It All Works

### **Execution Order (Dependency Chain)**

```
1. Fetch Root OU
   ↓
2. Create Production OU ← needs root ID
   Create Staging OU ← needs root ID
   ↓
3. Create AWS Accounts ← depends_on OUs
   ├─ freshdesk-prod
   ├─ freshdesk-staging
   ├─ freshservice-prod
   ├─ freshservice-staging
   ├─ freshsales-prod
   └─ freshsales-staging
   ↓
4. Move Prod Accounts to Production OU ← depends_on accounts
   ├─ freshdesk-prod → Production OU
   ├─ freshservice-prod → Production OU
   └─ freshsales-prod → Production OU
   ↓
5. Move Staging Accounts to Staging OU ← depends_on accounts
   ├─ freshdesk-staging → Staging OU
   ├─ freshservice-staging → Staging OU
   └─ freshsales-staging → Staging OU
   ↓
6. Generate Outputs (OU IDs, Account mappings)
```

---

## 🔐 Cross-Account Communication (How New Accounts are Managed)

### **The Question: How does Management Account access new accounts created by terraform?**

### **The Answer: AWS Organizations Auto-Creates Cross-Account Role**

When terraform creates a new account, **AWS automatically creates** a role in that new account:

```
terraform creates account
    ↓
AWS Organizations API
    ↓
New Account Created (Account ID: 987654321098)
    ↓
AWS AUTO-Creates Role in New Account:
  Role Name: OrganizationAccountAccessRole
  Trust Policy: Allows Management Account
  Permissions: Admin (all AWS services)
```

**What this means:**
- You DON'T need to create cross-account roles in your terraform code
- AWS does it automatically when the account is created
- Management Account can assume this role and manage the new account
- This is a built-in AWS Organizations feature

### **How terraform Uses It**

```
terraform in Management Account
    ↓
Creates account via: aws_organizations_account resource
    ↓
AWS Organizations API creates account
    ↓
AWS auto-creates: OrganizationAccountAccessRole (in new account)
    ↓
terraform can now provision resources in new account via cross-account access
    ↓
Result: terraform can create IAM roles, SCPs, etc. in member accounts
```

### **Real Example**

```hcl
# Your code
resource "aws_organizations_account" "freshdesk_prod" {
  name  = "freshdesk-prod"
  email = "aws+freshdesk-prod@freshworks.com"
}

# What AWS does automatically:
✅ Creates account: 987654321098
✅ Creates role: OrganizationAccountAccessRole (in 987654321098)
✅ Role trusts: Management Account
✅ Role permissions: Admin

# Result:
Management Account can now manage 987654321098 via cross-account access
```

### **Trust Policy (Auto-Created by AWS)**

AWS creates this automatically (you don't code it):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Translation:** *"Management Account can assume me and do anything"*

### **Why You Don't Need to Create Roles**

| Scenario | Need to Create Role? |
|----------|----------------------|
| Accounts created via AWS Organizations API | ❌ No (AWS creates auto) |
| Accounts in your organization | ❌ No (AWS creates auto) |
| Cross-account access in same organization | ❌ No (AWS creates auto) |
| Manual account setup | ❌ No (AWS creates auto) |
| Cross-account access between different orgs | ✅ Yes (manual setup) |

---

## 📊 Data Flow

### **Input Variables**
```hcl
accounts = {
  "freshdesk-prod" = {
    email       = "aws+freshdesk-prod@freshworks.com"
    project     = "freshdesk"
    environment = "prod"
  }
  ...
}
```

### **Processing (main.tf)**
```
For each account in var.accounts:
  1. Create account with name, email, tags
  2. Filter by environment
  3. Move prod accounts → Production OU
  4. Move staging accounts → Staging OU
```

### **Output (outputs.tf)**
```
Returns:
- production_ou_id: ou-1234-abcd5678
- staging_ou_id: ou-1234-efgh9012
- created_accounts: { account details }
- account_mapping: { account_id → name }
- production_accounts: { prod accounts }
- staging_accounts: { staging accounts }
```

---

## 🎯 Quick Reference - What Each Resource Does

| Resource | Creates | Count | Purpose | Auto-Created by AWS? |
|----------|---------|-------|---------|---------------------|
| `aws_organizations_organization` (data) | - | 1 (read) | Get Root OU ID | - |
| `aws_organizations_organizational_unit.production` | Production OU | 1 | Organize prod accounts | - |
| `aws_organizations_organizational_unit.staging` | Staging OU | 1 | Organize staging accounts | - |
| `aws_organizations_account.accounts` | AWS Accounts | 6 | Actual AWS accounts | ✅ OrganizationAccountAccessRole in each new account |
| `aws_organizations_organizational_unit_parent.prod_accounts` | - | 3 | Link prod accounts to OU | - |
| `aws_organizations_organizational_unit_parent.staging_accounts` | - | 3 | Link staging accounts to OU | - |

---

## 🚀 Running Terraform

```bash
# Initialize
terraform init

# Plan (see what will be created)
terraform plan

# Apply (actually create resources)
terraform apply

# View outputs
terraform output

# Destroy (remove everything)
terraform destroy
```

---

## ⚠️ Important Notes

1. **Email Subaddressing:** `aws+freshdesk-prod@freshworks.com`
   - All emails go to `aws@freshworks.com`
   - The `+tag` is for organization and filtering

2. **Non-Destructive:** `close_on_deletion = false`
   - Even if you run `terraform destroy`
   - AWS accounts are NOT deleted
   - Prevents accidental account loss

3. **Ignore Email Changes:** `ignore_changes = [email]`
   - If someone manually changes the email in AWS
   - Terraform won't revert it
   - Useful for sensitive changes

4. **Dependencies Matter:** `depends_on` ensures correct order
   - OUs created before accounts
   - Accounts created before moving to OUs
   - Prevents "parent OU not found" errors

5. **Cross-Account Access (Automatic):**
   - When terraform creates a new account, AWS automatically creates `OrganizationAccountAccessRole` in that account
   - This role trusts the Management Account
   - You DON'T need to create cross-account roles manually
   - AWS Organizations handles it automatically

---

## 💾 State File

Terraform stores state in `terraform.tfstate` (or remote backend)

**Contains:**
- All created resource IDs
- All resource properties
- Account IDs, OU IDs, etc.

**Never commit to git!** (contains sensitive data)

---

## 📌 Quick Recall Checklist

- [ ] `for_each` = loop through accounts map
- [ ] `if account.environment == "prod"` = filter only prod
- [ ] `data` source = read-only (fetch root OU)
- [ ] `depends_on` = wait for OUs before creating accounts
- [ ] `provider = aws.management` = use Management Account
- [ ] `ignore_changes = [email]` = don't overwrite manual changes
- [ ] `close_on_deletion = false` = don't delete accounts if Terraform destroyed
- [ ] Outputs = export OU IDs, account mappings for downstream use
