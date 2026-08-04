# 🚀 AFT Deployment Checklist

Complete this checklist step-by-step to deploy AWS Account Factory for Terraform with K8s CI/CD.

---

## 📋 Pre-Deployment Setup

### Prerequisites
- [ ] AWS Account (Management Account with Organizations enabled)
- [ ] AWS Control Tower landing zone created
- [ ] EKS Kubernetes cluster running in same AWS account
- [ ] kubectl configured to access the cluster
- [ ] GitHub repository with ARC runners deployed
- [ ] AWS CLI v2 installed and configured
- [ ] Terraform v1.0+ installed locally

---

## 🔐 Step 1: Create IAM Role & S3 Backend

### 1.1 Apply S3 Backend and IAM Role

```bash
cd terraform

# Plan to see what will be created
terraform plan -target=aws_iam_role.terraform_k8s_role \
                 -target=aws_s3_bucket.terraform_state \
                 -target=aws_s3_bucket.terraform_state_logs

# Apply to create resources
terraform apply -target=aws_iam_role.terraform_k8s_role \
                 -target=aws_s3_bucket.terraform_state \
                 -target=aws_s3_bucket.terraform_state_logs
```

- [ ] TerraformK8sRole IAM role created
- [ ] S3 bucket created (terraform-state-aft-ACCOUNT_ID)
- [ ] Access logs bucket created

### 1.2 Update backend.tf

```bash
# Get current account ID
terraform output current_account_id

# Copy backend.tf.example to backend.tf
cp terraform/backend.tf.example terraform/backend.tf

# Edit backend.tf with actual value
# Replace ACCOUNT_ID in bucket name with your AWS account ID
# Example: bucket = "terraform-state-aft-123456789012"
```

- [ ] backend.tf created with correct S3 bucket name
- [ ] ACCOUNT_ID replaced in bucket name

### 1.3 Migrate State to S3

```bash
# Initialize terraform with S3 backend
terraform init

# Confirm: Type "yes" when prompted to migrate state
```

- [ ] Terraform state migrated to S3
- [ ] Local terraform.tfstate file backed up (optional)

---

## 🔑 Step 2: EKS OIDC Provider Setup (for IRSA)

### 2.1 Create EKS OIDC Provider

```bash
# Get EKS cluster details
export CLUSTER_NAME=your-cluster-name
export AWS_REGION=us-east-1

# Get cluster OIDC provider
export OIDC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.identity.oidc.issuer' \
  --output text | cut -d'/' -f5)

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://oidc.eks.$AWS_REGION.amazonaws.com/id/$OIDC_ID \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $(curl -s https://oidc.eks.$AWS_REGION.amazonaws.com/id/$OIDC_ID/.well-known/openid-configuration | \
    jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} openssl s_client -servername {} -connect {}:443 </dev/null 2>/dev/null | \
    openssl x509 -fingerprint -noout | sed 's/://g' | cut -d'=' -f2)
```

- [ ] EKS OIDC provider created in AWS
- [ ] EKS OIDC ID noted: `$OIDC_ID`
- [ ] AWS region noted: `$AWS_REGION`

### 2.2 Update iam-roles.tf for K8s

```bash
# Edit terraform/iam-roles.tf and update lines 187, 196, 202:
# Replace "YOUR_AWS_REGION" with actual region (e.g., us-east-1)
# Replace "YOUR_CLUSTER_ID" with actual OIDC ID (from above)

# Example:
# oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E
```

- [ ] AWS region updated in iam-roles.tf (lines 187, 196, 202)
- [ ] EKS cluster OIDC ID updated in iam-roles.tf (lines 187, 196, 202)

---

## 📦 Step 3: Kubernetes Deployment

### 3.1 Deploy K8s Namespaces & RBAC

```bash
# Apply namespace and RBAC
kubectl apply -f k8s/1-namespace.yaml
kubectl apply -f k8s/2-rbac.yaml

# Verify
kubectl get namespace arc-system aft-terraform
kubectl get sa -n aft-terraform terraform-sa -o yaml | grep role-arn
```

- [ ] arc-system namespace created
- [ ] aft-terraform namespace created
- [ ] Service accounts created with IRSA annotations
- [ ] RBAC roles and bindings created

### 3.2 Deploy GitHub PAT Secret

```bash
# Update 3-secret-github-token.yaml with your GitHub PAT
# Replace: ghp_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q

# Apply secret
kubectl apply -f k8s/3-secret-github-token.yaml

# Verify (shows base64 encoded, that's normal)
kubectl get secret github-token -n arc-system -o yaml
```

- [ ] GitHub PAT secret created in arc-system namespace
- [ ] Secret verified with correct value

### 3.3 Deploy ARC Runners

```bash
# Apply runner deployment
kubectl apply -f k8s/4-actions-runner-deployment.yaml

# Wait for runners to be ready (2-3 minutes)
kubectl wait --for=condition=Ready pod \
  -l runner-type=aft \
  -n arc-system \
  --timeout=300s

# Verify runners are online
kubectl get pods -n arc-system
```

- [ ] Runner deployment created (2 replicas)
- [ ] Runner pods in Running state
- [ ] Runners registered in GitHub (Settings → Actions → Runners)

### 3.4 Verify IRSA Setup

```bash
# Check if IRSA webhook is injecting credentials
kubectl describe pod terraform-plan-xxxxx -n aft-terraform \
  | grep -A 5 "AWS_ROLE_ARN"

# Or check service account annotation
kubectl get sa terraform-sa -n aft-terraform -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

- [ ] IRSA webhook installed on EKS cluster
- [ ] terraform-sa has IRSA annotation with correct role ARN

---

## 🔄 Step 4: GitHub & Terraform Configuration

### 4.1 Update Terraform Workflows

```bash
# Update both workflow files with correct values:
# File: .github/workflows/terraform-plan.yml
# File: .github/workflows/terraform-apply.yml

# Replace in both files:
# MANAGEMENT-ACCOUNT-ID → Your actual AWS account ID (e.g., 123456789012)

# Verify changes
grep -n "MANAGEMENT-ACCOUNT-ID" .github/workflows/terraform-plan.yml
grep -n "MANAGEMENT-ACCOUNT-ID" .github/workflows/terraform-apply.yml
# Should show: 0 results (all replaced)
```

- [ ] terraform-plan.yml updated with account ID
- [ ] terraform-apply.yml updated with account ID

### 4.2 Commit and Push

```bash
# Commit changes
git add terraform/ k8s/ .github/workflows/
git commit -m "feat: configure AFT with IAM roles, backend, and K8s deployment"

# Push to GitHub
git push origin main
```

- [ ] Changes committed to git
- [ ] Changes pushed to GitHub repository

---

## 🏗️ Step 5: Terraform Deployment

### 5.1 Deploy OUs & Accounts

```bash
cd terraform

# Plan to review all changes
terraform plan

# Apply to create resources
terraform apply

# Review outputs
terraform output created_accounts
terraform output production_ou_id
terraform output staging_ou_id
```

- [ ] OUs created (Production, Staging)
- [ ] AWS Accounts created (6 total)
- [ ] Accounts in correct OUs
- [ ] SCPs attached to OUs

### 5.2 Verify Accounts

```bash
# List all accounts
aws organizations list-accounts --output table

# List OUs
aws organizations list-organizational-units-for-parent --parent-id r-xxxx

# Check SCPs on OUs
aws organizations list-policies-for-target --target-id ou-xxxx-xxxxxxxx --filter SERVICE_CONTROL_POLICY
```

- [ ] All 6 accounts created successfully
- [ ] Accounts show correct email addresses
- [ ] Accounts in correct OUs
- [ ] SCPs attached properly

---

## ✅ Step 6: Verification & Testing

### 6.1 Test GitHub Workflows

```bash
# Create test PR with terraform change
git checkout -b test/verify-workflow
# Make a small change to terraform/terraform.tfvars

# Push and create PR
git push origin test/verify-workflow

# Go to GitHub → Pull Requests → View Actions
# Watch for terraform-plan.yml workflow to run
```

- [ ] terraform-plan.yml workflow triggered
- [ ] Plan runs successfully
- [ ] Plan output appears on PR
- [ ] GitHub Actions runners picked up the job

### 6.2 Test terraform-apply

```bash
# After PR approval and merge to main
git checkout main
git pull

# Watch GitHub → Actions
# terraform-apply.yml should run automatically
# Check workflow status and logs
```

- [ ] terraform-apply.yml workflow triggered on merge
- [ ] Apply runs successfully
- [ ] AWS resources created/updated
- [ ] Commit comment shows apply results

### 6.3 Test SCP Restrictions

```bash
# In a production account, try to create EC2 without tags
aws ec2 run-instances --image-id ami-xxxxx \
  --instance-type t2.micro \
  --region eu-west-1  # Not in approved list

# Expected: ❌ DENIED by SCP (region restriction)

# Try with tags in correct region
aws ec2 run-instances --image-id ami-xxxxx \
  --instance-type t2.micro \
  --region us-east-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Primary,Value=test},{Key=Secondary,Value=prod},{Key=Service,Value=web}]'

# Expected: ✅ ALLOWED
```

- [ ] SCP region restriction working
- [ ] SCP tagging requirement working
- [ ] SCP prod-specific restrictions working

---

## 🎯 Post-Deployment Checklist

### Security & Monitoring

- [ ] Enable CloudTrail logging to S3 (audit trail)
- [ ] Set up CloudWatch alarms for failed deployments
- [ ] Enable MFA delete on S3 state bucket
- [ ] Review and tighten S3 bucket policies if needed
- [ ] Document OIDC provider setup for team

### Cleanup & Documentation

- [ ] Remove backend.tf.example (or update .gitignore)
- [ ] Update README.md with deployment summary
- [ ] Document AWS account purposes and contacts
- [ ] Create runbook for common operations
- [ ] Update team wiki/docs with AFT setup details

### Ongoing Maintenance

- [ ] Set up automated backups of terraform state
- [ ] Schedule regular SCP reviews (quarterly)
- [ ] Monitor S3 costs (state storage)
- [ ] Track Account Factory resource usage
- [ ] Plan for future OU/account additions

---

## 🆘 Troubleshooting

### K8s Pod Fails: "Unable to assume role via OIDC"

```
Issue: Terraform pod cannot assume TerraformK8sRole
Fix:
1. Verify EKS OIDC provider exists: aws iam list-open-id-connect-providers
2. Verify service account has IRSA annotation: kubectl get sa terraform-sa -n aft-terraform -o yaml
3. Check IRSA webhook is installed: kubectl get pods -n kube-system | grep irsa
4. Verify role ARN in annotation matches AWS role
```

### S3 State Lock Issue

```
Issue: "Error acquiring the state lock"
Fix:
1. Check S3 bucket exists: aws s3 ls | grep terraform-state-aft
2. Verify bucket has correct IAM permissions in iam-roles.tf
3. Check for stale .terraform.lock.hcl file in local directory
4. If stuck, list S3 lock files: aws s3api list-objects --bucket terraform-state-aft-ACCOUNT_ID --prefix aft/
```

### SCP Not Enforcing

```
Issue: Resource created despite SCP
Fix:
1. Verify SCP attached to correct OU: aws organizations list-policies-for-target --target-id ou-xxxx
2. Check account inherits SCP from parent OU
3. SCPs don't apply to root account
4. Wait 5 minutes after attachment for propagation
```

---

## 📞 Support & Escalation

**Questions about:**
- **Terraform**: Check TERRAFORM-NOTES.md
- **GitHub Actions**: Check GITHUB-ACTIONS-NOTES.md
- **K8s Setup**: Check k8s/ directory README
- **AWS Resources**: Check AWS Organizations console

**Issue not listed?**
1. Check CloudTrail logs for detailed error messages
2. Review workflow logs in GitHub Actions UI
3. Check EKS pod logs: `kubectl logs -f <pod-name> -n aft-terraform`
4. Check IAM role trust policies and permissions

---

## ✨ Congratulations!

Once all steps are complete:
- ✅ Your Landing Zone is deployed
- ✅ Accounts are organized
- ✅ CI/CD pipeline is active
- ✅ SCPs enforce governance
- ✅ Infrastructure as Code is implemented

**Next steps:**
- Enroll accounts in Control Tower
- Apply Control Tower guardrails
- Set up AWS identity Center / SSO
- Create custom OUs as needed
- Scale to additional workloads

---

## 📋 Status Tracking

Mark your progress:

```
Setup:        [ ] OIDC [ ] IAM [ ] S3 Backend [ ] K8s [ ] GitHub
Testing:      [ ] Plan [ ] Apply [ ] SCP [ ] Verify
Finalization: [ ] Docs [ ] Cleanup [ ] Monitoring
```
