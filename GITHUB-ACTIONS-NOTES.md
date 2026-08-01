# 🚀 GitHub Actions AFT - Quick Reference & Recall Guide

## 📖 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Workflow Files](#workflow-files)
3. [terraform-plan.yml Explained](#terraform-planymyml-explained)
4. [terraform-apply.yml Explained](#terraform-applyymyml-explained)
5. [Key Concepts](#key-concepts)
6. [Complete Flow](#complete-flow)
7. [Data Flow Diagram](#data-flow-diagram)
8. [IRSA in Workflows](#irsa-in-workflows)
9. [Troubleshooting](#troubleshooting)
10. [Quick Reference](#quick-reference)

---

## 🏗️ Architecture Overview

**What do these workflows do?**

```
Developer: git push → GitHub detects change → Workflow triggered
                ↓
    ARC Runner Pod receives job (in arc-system namespace)
                ↓
    Workflow creates temporary terraform pod (in aft-terraform namespace)
                ↓
    Terraform pod uses IRSA to get AWS credentials
                ↓
    Runs terraform plan/apply
                ↓
    Workflow comments results on PR/commit
                ↓
    Temporary pod deleted (cleanup)
```

---

## 📁 Workflow Files

| File | Triggered By | Purpose |
|------|-------------|---------|
| `terraform-plan.yml` | Pull Request to main/develop | Run terraform plan (review) |
| `terraform-apply.yml` | Push to main | Run terraform apply (execute) |

---

## 🔍 terraform-plan.yml Explained

### **SECTION 1: Trigger Configuration (Lines 1-11)**

```yaml
name: Terraform Plan

on:
  pull_request:
    branches:
      - main
      - develop
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-plan.yml'
  workflow_dispatch:
```

**What triggers this workflow:**

| Trigger | When It Fires |
|---------|---------------|
| `pull_request` | PR is opened/updated |
| `branches: [main, develop]` | ONLY if PR targets main or develop |
| `paths: ['terraform/**']` | ONLY if changes in terraform/ folder |
| `workflow_dispatch` | Manual trigger from GitHub UI (workflow button) |

**Real Examples:**
```
❌ Developer changes README.md → NO trigger (not in paths)
❌ Developer changes code on feature branch → NO trigger (not PR to main/develop)
✅ Developer changes terraform/main.tf → TRIGGER PLAN workflow
✅ Developer changes .github/workflows/terraform-plan.yml → TRIGGER (watches itself)
```

---

### **SECTION 2: Permissions (Lines 13-15)**

```yaml
permissions:
  contents: read
  pull-requests: write
```

**What this allows:**

| Permission | Allows |
|-----------|--------|
| `contents: read` | Read the repository code and files |
| `pull-requests: write` | Comment on PRs, post status checks |

**Why needed:** To comment terraform plan output on the PR

---

### **SECTION 3: Job Configuration (Lines 17-18)**

```yaml
jobs:
  plan:
    name: Terraform Plan
    runs-on: [self-hosted, aft-runner]
```

**What this means:**

| Setting | Explanation |
|---------|-------------|
| `jobs:` | Start defining workflow jobs |
| `plan:` | Job ID (internal reference) |
| `name:` | Display name in GitHub UI |
| `runs-on: [self-hosted, aft-runner]` | **Run on our K8s ARC runner** (not GitHub's servers) |

**Key Point:** `self-hosted` = our infrastructure (K8s pod), not GitHub's runners

---

### **SECTION 4: Checkout Code (Lines 20-21)**

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

**What it does:**
```bash
# Under the hood:
git clone https://github.com/your-repo.git /tmp/workspace
cd /tmp/workspace
git checkout <branch>
```

**Result:** All terraform files available in the ARC pod

---

### **SECTION 5: Create Terraform Plan Pod (Lines 23-121)** ⭐ **KEY STEP**

```yaml
- name: Create Terraform Plan Pod (IRSA)
  id: plan
  run: |
    set -e
```

**This is the main step. Breaking it down:**

#### **Step A: Prepare terraform code (Lines 27-30)**
```bash
mkdir -p /tmp/terraform-${{ github.run_id }}
cp -r terraform/* /tmp/terraform-${{ github.run_id }}/
```

- Creates temp directory with unique ID
- `${{ github.run_id }}` = workflow run number (e.g., 12345)
- Copies all terraform files there

**Why?** K8s needs files in a format it can use (ConfigMap)

---

#### **Step B: Create ConfigMap (Lines 32-36)**
```bash
kubectl create configmap terraform-code-${{ github.run_id }} \
  --from-file=/tmp/terraform-${{ github.run_id }}/ \
  -n aft-terraform \
  --dry-run=client -o yaml | kubectl apply -f -
```

**What's a ConfigMap?**
- K8s resource for storing files/data
- Makes files available to pods

**Example ConfigMap:**
```
Name: terraform-code-12345
Contents:
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars
```

**Flags:**
- `--from-file=` : Store files from directory
- `-n aft-terraform` : Create in aft-terraform namespace
- `--dry-run=client -o yaml` : Preview what will be created
- `| kubectl apply -f -` : Actually create it

---

#### **Step C: Create Pod Manifest (Lines 38-92)**

```bash
cat > /tmp/terraform-plan-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: terraform-plan-${{ github.run_id }}
  namespace: aft-terraform
  labels:
    app: aft
    component: terraform
    job: plan
spec:
  serviceAccountName: terraform-sa  # ← IRSA!
  restartPolicy: Never
  containers:
    - name: terraform
      image: hashicorp/terraform:latest
      workingDir: /terraform
      env:
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"
        - name: TF_INPUT
          value: "false"
      volumeMounts:
        - name: terraform-code
          mountPath: /terraform  # Mount here
        - name: output
          mountPath: /output     # Output goes here
      command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "🚀 Starting Terraform Plan (with IRSA)..."

          terraform init
          terraform validate
          terraform fmt -check -recursive || true
          terraform plan -no-color -out=tfplan
          terraform show -no-color tfplan > /output/plan.txt

          echo "✅ Plan completed successfully"
  volumes:
    - name: terraform-code
      configMap:
        name: terraform-code-${{ github.run_id }}
    - name: output
      emptyDir: {}
EOF
```

**Breaking this down:**

| Section | Purpose |
|---------|---------|
| `kind: Pod` | Create a K8s Pod |
| `name: terraform-plan-12345` | Unique name per workflow run |
| `namespace: aft-terraform` | Create in aft-terraform namespace |
| `serviceAccountName: terraform-sa` | Use service account WITH IRSA |
| `image: hashicorp/terraform:latest` | Terraform pre-installed |
| `workingDir: /terraform` | Change to /terraform directory |
| `volumeMounts` | Where to mount files |
| `terraform-code` → `/terraform` | ConfigMap mounted as /terraform |
| `output` → `/output` | Empty volume for output files |
| `command:` | Script to run when pod starts |

**Key: IRSA Magic**
```
Pod starts with terraform-sa service account
    ↓
K8s IRSA webhook intercepts
    ↓
Webhook reads IRSA annotation from service account
    ↓
Webhook injects OIDC token into pod
    ↓
Terraform SDK receives token + role ARN
    ↓
AWS STS converts OIDC token → temporary credentials
    ↓
Terraform has AWS credentials automatically! ✅
    ↓
NO SECRETS stored in pod! 🔒
```

---

#### **Step D: Apply the Pod (Line 94)**
```bash
kubectl apply -f /tmp/terraform-plan-pod.yaml
```

- Creates the pod from the manifest
- Pod immediately starts executing the command

---

#### **Step E: Wait for Pod Completion (Lines 96-108)**

```bash
echo "⏳ Waiting for terraform plan pod to complete..."

kubectl wait --for=condition=Ready pod/terraform-plan-${{ github.run_id }} \
  -n aft-terraform \
  --timeout=5m || true

kubectl wait --for=condition=Completed pod/terraform-plan-${{ github.run_id }} \
  -n aft-terraform \
  --timeout=10m || kubectl get pod terraform-plan-${{ github.run_id }} \
  -n aft-terraform -o yaml
```

**Timeline:**
```
T0: kubectl apply → Pod created
T1: Pod starts → terraform init begins
T2-T3: terraform downloading providers
T4-T5: terraform plan running
T6: Pod completes → Workflow continues
```

**Flags:**
- `--for=condition=Ready` : Wait until pod is ready
- `--for=condition=Completed` : Wait until pod finishes
- `--timeout=10m` : Max wait time (10 minutes for plan)
- `|| true` : Don't fail if timeout

---

#### **Step F: Copy Output Back (Lines 110-124)**

```bash
mkdir -p terraform

kubectl cp aft-terraform/terraform-plan-${{ github.run_id }}:/output/plan.txt \
  terraform/plan.txt || echo "No plan output found"

kubectl cp aft-terraform/terraform-plan-${{ github.run_id }}:/output/output.json \
  terraform/output.json || echo "No output found"

echo "📋 Plan:"
cat terraform/plan.txt || true
echo ""
echo "📤 Outputs:"
cat terraform/output.json || true

echo "plan_exit_code=0" >> $GITHUB_OUTPUT
```

**What happens:**
```
Pod filesystem (in K8s)
    /output/plan.txt (inside pod)
         ↓ kubectl cp
    terraform/plan.txt (ARC pod filesystem)
         ↓ cat
    Display in logs
```

**Files copied:**
- `plan.txt` : Readable terraform plan output
- `output.json` : Terraform outputs in JSON

---

### **SECTION 6: Save Plan Artifact (Lines 123-129)**

```yaml
- name: Save plan artifact (from pod)
  uses: actions/upload-artifact@v3
  if: always()
  with:
    name: tfplan-${{ github.run_id }}
    path: terraform/plan.txt
    retention-days: 1
```

**What it does:**
- Uploads `plan.txt` to GitHub
- Available for download for 1 day
- Visible in workflow run → Artifacts

**Why?** terraform-apply workflow can download and reference this plan later

---

### **SECTION 7: Cleanup Pod (Lines 131-138)**

```yaml
- name: Cleanup terraform plan pod
  if: always()
  run: |
    kubectl delete pod terraform-plan-${{ github.run_id }} \
      -n aft-terraform \
      --ignore-not-found=true

    kubectl delete configmap terraform-code-${{ github.run_id }} \
      -n aft-terraform \
      --ignore-not-found=true
```

**What it does:**
- Deletes the temporary terraform pod
- Deletes the temporary configmap
- `if: always()` = run even if previous steps failed
- `--ignore-not-found=true` = don't error if already deleted

**Why?** Clean up K8s cluster, no orphaned resources

---

### **SECTION 8: Comment on PR (Lines 140-166)**

```yaml
- name: Comment plan on PR
  uses: actions/github-script@v7
  if: github.event_name == 'pull_request'
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      const fs = require('fs');
      const plan = fs.readFileSync('terraform/plan.txt', 'utf8');

      let body = '## 📋 Terraform Plan\n\n';

      if (plan.includes('No changes')) {
        body += '✅ **No changes detected**\n\n';
      } else {
        body += '### Changes:\n\n';
        body += '```\n' + plan + '\n```\n\n';
      }

      body += '---\n';
      body += '*This comment was automatically generated by Terraform Plan workflow*\n';
      body += 'Commit: `' + context.payload.pull_request.head.sha.substring(0, 7) + '`\n';

      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: body
      });
```

**Breaking it down:**

1. **Read plan file:**
   ```javascript
   const plan = fs.readFileSync('terraform/plan.txt', 'utf8');
   ```

2. **Build comment body:**
   ```javascript
   if (plan.includes('No changes')) {
     body += '✅ **No changes detected**\n\n';
   } else {
     body += '### Changes:\n\n';
     body += '```\n' + plan + '\n```\n\n';
   }
   ```

3. **Post to GitHub API:**
   ```javascript
   github.rest.issues.createComment({
     issue_number: context.issue.number,  // Which PR? PR #42
     owner: context.repo.owner,           // Which org? your-org
     repo: context.repo.repo,             // Which repo? your-repo
     body: body                           // The comment text
   });
   ```

**Result on PR:**
```
┌──────────────────────────────────────┐
│ PR #42: Add new accounts             │
│                                      │
│ 📋 Terraform Plan                   │
│                                      │
│ Changes:                             │
│ ┌──────────────────────────────────┐ │
│ │ + aws_organizations_account.     │ │
│ │   freshdesk-prod                 │ │
│ │ + aws_organizations_account.     │ │
│ │   freshservice-prod              │ │
│ │                                  │ │
│ │ Plan: 6 to add, 0 to change     │ │
│ └──────────────────────────────────┘ │
│                                      │
│ Commit: abc1234                     │
└──────────────────────────────────────┘
```

---

### **SECTION 9: Post to Job Summary (Lines 168-174)**

```yaml
- name: Post plan to job summary
  if: always()
  run: |
    echo "## Terraform Plan Results" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
    cat terraform/plan.txt >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
```

**What it does:**
- Appends plan output to workflow job summary
- Visible in "Summary" tab
- Survives even if PR comments are deleted

---

## 📋 terraform-apply.yml Explained

**Similar to terraform-plan.yml with differences:**

### **Trigger (Lines 1-9)**
```yaml
on:
  push:
    branches: [main]  # ← ONLY on main branch!
    paths: ['terraform/**']
```

**Key difference:** Triggered on PUSH to main (not PR)

---

### **Pod Configuration (Differences)**

Same structure as plan, but:

```yaml
command:
  - /bin/sh
  - -c
  - |
    set -e
    echo "🚀 Starting Terraform Apply (with IRSA)..."

    terraform init
    terraform validate
    terraform plan -no-color -out=tfplan
    terraform show -no-color tfplan > /output/plan.txt

    echo "⚙️  Running terraform apply..."
    terraform apply -no-color -auto-approve tfplan  # ← KEY DIFFERENCE

    echo "📤 Collecting outputs..."
    terraform output -json > /output/output.json

    echo "✅ Apply completed successfully"
```

**Key steps:**
1. ✅ terraform init
2. ✅ terraform plan (for review)
3. ✅ **terraform apply -auto-approve** (actually create resources!)
4. ✅ terraform output -json (capture outputs)

---

### **Commit Comment (Lines 138-169)**

Instead of PR comment, posts to commit:

```yaml
- name: Create deployment commit comment
  uses: actions/github-script@v7
  if: success()
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      const fs = require('fs');
      const plan = fs.readFileSync('terraform/plan.txt', 'utf8');
      const output = JSON.parse(fs.readFileSync('terraform/output.json', 'utf8'));

      let body = '## ✅ Terraform Apply - Completed\n\n';

      body += '### Summary\n';
      body += `- **Status**: Success\n`;
      body += `- **Commit**: ${context.sha.substring(0, 7)}\n`;
      body += `- **Author**: ${context.actor}\n`;
      body += `- **Time**: ${new Date().toISOString()}\n\n`;

      body += '### Changes Applied\n';
      body += '```\n' + plan + '\n```\n\n';

      body += '### Outputs\n';
      body += '```json\n' + JSON.stringify(output, null, 2) + '\n```\n\n';

      github.rest.repos.createCommitComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        commit_sha: context.sha,
        body: body
      });
```

**Posts to commit (not PR):**
```
Commit abc1234
└─ Comment: "✅ Terraform Apply - Completed"
   - Status: Success
   - Author: user-name
   - Time: 2026-08-01T...
   - Changes Applied: [list]
   - Outputs: [json]
```

---

### **Failure Notification (Lines 191-203)**

```yaml
- name: Notify on failure
  if: failure()
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      github.rest.repos.createCommitComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        commit_sha: context.sha,
        body: '## ❌ Terraform Apply - Failed\n\n' +
              'Check the workflow logs for details.\n' +
              '[View Workflow Logs](https://github.com/${ context.repo.owner }/${ context.repo.repo }/actions/runs/${ context.runId })'
      });
```

**Posts failure notification to commit with link to logs**

---

## 💡 Key Concepts

### **1. Self-Hosted Runner**
```yaml
runs-on: [self-hosted, aft-runner]
```
- Uses our ARC K8s pod (not GitHub's servers)
- Labeled with `aft-runner` to identify our runners
- Available whenever pod is running

---

### **2. ConfigMap**
- K8s resource for storing files/data
- Makes terraform code available to pods
- Created per workflow run, deleted after

---

### **3. kubectl Commands**
```bash
kubectl create configmap  # Create K8s resource with files
kubectl apply -f         # Create/update from manifest
kubectl wait             # Block until pod finishes
kubectl cp              # Copy files between pod and host
kubectl delete          # Remove pod/resource
kubectl exec            # Run command inside pod
```

---

### **4. IRSA (IAM Roles for Service Accounts)**
```
Service Account (K8s) ← IRSA annotation
    ↓
K8s OIDC webhook
    ↓
AWS STS
    ↓
Temporary credentials (no secrets stored!)
```

---

### **5. github-script**
```yaml
uses: actions/github-script@v7
script: |
  # JavaScript code here
  # Access GitHub API via: github.rest.*
  # Access context via: context.*
```

---

### **6. Environment Variables**
```yaml
${{ github.run_id }}           # Workflow run number
${{ secrets.GITHUB_TOKEN }}    # GitHub token (auto-provided)
${{ github.event_name }}       # What triggered workflow (pull_request/push)
context.issue.number           # PR number
context.actor                  # Who triggered workflow
context.sha                    # Commit SHA
```

---

## 🔄 Complete Flow

```
Step 1: Developer Push
├─ Developer: git push terraform/main.tf
├─ GitHub detects: Change in terraform/ on main/develop branch
└─ Triggers: terraform-plan.yml workflow

Step 2: ARC Runner Receives Job
├─ ARC pod (arc-system) receives GitHub job
├─ Workspace cloned into pod
└─ Workflow steps start executing

Step 3: Checkout Code
├─ git clone repo
├─ Checkout correct branch
└─ All terraform files available

Step 4: Create ConfigMap
├─ Copy terraform code to /tmp/terraform-12345
├─ Create K8s ConfigMap with the files
└─ ConfigMap available in aft-terraform namespace

Step 5: Create Terraform Pod
├─ Create Pod manifest
├─ Pod uses terraform-sa service account
├─ IRSA webhook injects OIDC token
├─ AWS STS provides temporary credentials
└─ terraform pod starts executing

Step 6: Terraform Plan
├─ terraform init (download providers)
├─ terraform validate (check syntax)
├─ terraform plan (check what will change)
└─ Save output to /output/plan.txt

Step 7: Copy Output Back
├─ kubectl cp → Copy plan.txt from pod to ARC pod
├─ Display plan in workflow logs
└─ Save as artifact

Step 8: Comment on PR
├─ Read plan.txt
├─ Format as markdown comment
├─ Post to PR via GitHub API
└─ Developers see results on PR page

Step 9: Cleanup
├─ kubectl delete pod (remove temporary pod)
├─ kubectl delete configmap (remove temporary files)
└─ K8s cluster clean

Step 10: Developer Reviews PR
├─ Developer reads terraform plan comment
├─ Decides: Approve or request changes
└─ If approved: Merge to main

Step 11: Push to Main Triggers Apply
├─ Merge PR to main → Push event
├─ GitHub detects: Change in terraform/ on main
├─ Triggers: terraform-apply.yml workflow
└─ Repeat steps 2-9 but with terraform apply instead of plan

Step 12: Terraform Apply
├─ terraform apply -auto-approve tfplan
├─ AWS resources created/modified
├─ terraform output -json (collect outputs)
└─ Post success comment on commit

Step 13: Complete
├─ Infrastructure updated in AWS
├─ PR merged
├─ Everything clean in K8s
└─ Commit comment shows results
```

---

## 📊 Data Flow Diagram

```
GitHub Push/PR
    ↓
GitHub Actions Trigger
    ↓
ARC Runner Pod (arc-system)
├─ Checkout code
├─ Create ConfigMap (terraform code)
├─ kubectl apply → Create terraform pod
│   ↓
│   Terraform Pod (aft-terraform namespace)
│   ├─ Service Account: terraform-sa (IRSA)
│   ├─ AWS credentials via OIDC
│   ├─ terraform init/validate/plan
│   └─ Output to /output/plan.txt
├─ kubectl cp → Copy output back
├─ Comment on PR/commit
├─ Upload artifact
├─ kubectl delete → Cleanup pod
└─ Workflow complete
    ↓
Developer sees results on PR/commit
    ↓
(If approved) Merge to main
    ↓
terraform-apply.yml triggered
    ↓
Resources created in AWS ✅
```

---

## 🔐 IRSA in Workflows

### **How IRSA Works in the Pod**

```yaml
spec:
  serviceAccountName: terraform-sa  # ← Points to this
```

The `terraform-sa` service account has:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: terraform-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::MGMT-ACCOUNT:role/TerraformK8sRole
```

**Flow:**
```
Pod starts with terraform-sa
    ↓
K8s IRSA webhook watches pod startup
    ↓
Webhook sees IRSA annotation
    ↓
Webhook injects environment variables:
    - AWS_ROLE_ARN: arn:aws:iam::MGMT-ACCOUNT:role/TerraformK8sRole
    - AWS_WEB_IDENTITY_TOKEN_FILE: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    ↓
Terraform SDK reads these env vars
    ↓
SDK sends OIDC token to AWS STS
    ↓
STS validates token + role
    ↓
STS returns temporary credentials
    ↓
Terraform uses credentials ✅
```

**Key:** No secrets stored! Just a token exchange.

---

## 🐛 Troubleshooting

### **Workflow Failed: Pod Never Completed**
```bash
# Check pod status
kubectl get pods -n aft-terraform

# Check pod logs
kubectl logs terraform-plan-12345 -n aft-terraform

# Check pod events
kubectl describe pod terraform-plan-12345 -n aft-terraform
```

**Common causes:**
- ❌ IRSA not configured (no AWS credentials)
- ❌ Kubernetes API timeout (pod took too long)
- ❌ ConfigMap not created properly
- ❌ terraform-sa service account missing

---

### **PR Comment Never Posted**
```bash
# Check workflow logs for:
- ConfigMap creation errors
- kubectl cp errors
- GitHub API call failures

# Verify permissions:
- permissions.pull-requests: write (in workflow)
- GITHUB_TOKEN secret available
```

---

### **Artifact Upload Failed**
```bash
# Check:
- Does terraform/plan.txt exist?
- File size within limits?
- Workflow has write permissions?
```

---

### **Pod Stuck in Pending**
```bash
# Check cluster resources
kubectl top nodes

# Check pod description
kubectl describe pod terraform-plan-12345 -n aft-terraform

# Common causes:
- Not enough CPU/memory
- Node selector didn't match
- Image pull failed
```

---

## 📌 Quick Reference Checklist

### **Before Running Workflows:**
- [ ] Replace `MANAGEMENT-ACCOUNT-ID` in both workflows
- [ ] Replace `ghp_XXXX` in 3-secret-github-token.yaml
- [ ] ARC runners deployed (2 pods running in arc-system)
- [ ] terraform-sa created in aft-terraform namespace
- [ ] IRSA annotation on terraform-sa
- [ ] terraform code committed to repo

### **When Workflow Runs:**
- [ ] GitHub detects change in terraform/**
- [ ] ARC runner receives job
- [ ] terraform pod created in aft-terraform namespace
- [ ] Pod executes terraform plan/apply
- [ ] Output copied back to ARC pod
- [ ] Comment posted on PR/commit
- [ ] Pod deleted (cleanup)

### **If Something Breaks:**
- [ ] Check pod logs: `kubectl logs -n aft-terraform terraform-plan-XXXXX`
- [ ] Check pod status: `kubectl describe pod -n aft-terraform terraform-plan-XXXXX`
- [ ] Check workflow logs: GitHub UI → Actions → workflow run
- [ ] Verify IRSA: `kubectl get sa terraform-sa -n aft-terraform -o yaml`
- [ ] Verify AWS role exists and has trust policy

### **Manual Testing:**
```bash
# Deploy terraform pod manually
kubectl apply -f k8s/5-terraform-pod-irsa.yaml

# Connect and debug
kubectl exec -it terraform-executor -n aft-terraform -- /bin/bash

# Test AWS access (should work with IRSA)
aws sts get-caller-identity

# Cleanup
kubectl delete -f k8s/5-terraform-pod-irsa.yaml
```

---

## 📚 Key Variables & Secrets

| Variable | Source | Used For |
|----------|--------|----------|
| `${{ github.run_id }}` | GitHub | Unique pod name per run |
| `${{ secrets.GITHUB_TOKEN }}` | GitHub (auto) | Post comments to PR/commit |
| `MANAGEMENT-ACCOUNT-ID` | You update | AWS OIDC role ARN |
| `terraform-sa` | K8s | IRSA service account |
| AWS credentials | IRSA (OIDC) | terraform commands |

---

## 🎯 Common Patterns

### **Pattern 1: Reading Terraform Output**
```yaml
- name: Get Terraform Output
  run: |
    cd terraform
    terraform output -json > output.json
    cat output.json | jq '.production_ou_id.value'
```

---

### **Pattern 2: Posting to GitHub**
```javascript
github.rest.issues.createComment({
  issue_number: context.issue.number,
  owner: context.repo.owner,
  repo: context.repo.repo,
  body: "Comment text"
});
```

---

### **Pattern 3: Waiting for K8s Resource**
```bash
kubectl wait --for=condition=Ready pod/POD_NAME \
  -n NAMESPACE \
  --timeout=10m
```

---

## 🔗 Related Files

- `TERRAFORM-NOTES.md` - Terraform code reference
- `k8s/5-terraform-pod-irsa.yaml` - Pod template for manual runs
- `k8s/2-rbac.yaml` - terraform-sa service account definition
- `README.md` - Project overview

---

## 📞 Quick Reference Commands

```bash
# View workflow status
kubectl get pods -n aft-terraform -l job=plan

# Follow pod logs
kubectl logs -f terraform-plan-XXXXX -n aft-terraform

# Cleanup stuck pods
kubectl delete pods -n aft-terraform -l job=plan

# Check ConfigMaps
kubectl get configmaps -n aft-terraform

# Test IRSA manually
kubectl exec -it terraform-executor -n aft-terraform \
  -- aws sts get-caller-identity

# Trigger workflow manually
# Go to GitHub → Actions → Terraform Plan → Run workflow

# Rerun failed workflow
# GitHub UI → Actions → workflow run → Re-run
```

---

All key concepts documented! 🎉 Use this as your reference guide.
