# 🏗️ AFT Architecture Overview

## Single Role Architecture

### What You Need

```
┌─────────────────────────────────────────────────────────┐
│ AWS Account (Management)                                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐         ┌──────────────────────┐  │
│  │  TerraformK8s   │         │  S3 State Backend    │  │
│  │     Role        │────────→│  (terraform-state)   │  │
│  └─────────────────┘         └──────────────────────┘  │
│         ▲                                                │
│         │ IRSA                                          │
│         │ (K8s OIDC)                                    │
│         │                                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │           EKS Cluster                            │  │
│  │                                                   │  │
│  │  ┌──────────────────┐  ┌─────────────────────┐  │  │
│  │  │  arc-system      │  │  aft-terraform      │  │  │
│  │  ├──────────────────┤  ├─────────────────────┤  │  │
│  │  │ actions-runner   │  │ terraform-sa        │  │  │
│  │  │ (ARC runners)    │  │ (IRSA enabled)      │  │  │
│  │  │                  │  │                     │  │  │
│  │  │ - GitHub token   │  │ - AWS credentials   │  │  │
│  │  │ - No AWS access  │  │   (via IRSA)        │  │  │
│  │  └──────────────────┘  └─────────────────────┘  │  │
│  │                                                   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Deployment Flow

### 1️⃣ Developer Pushes Code

```
Developer
    ↓
git push to GitHub main/develop branch
    ↓
GitHub detects terraform/* file changes
```

### 2️⃣ GitHub Actions Workflow Triggered

```
GitHub Actions
    ↓
Assigns to ARC runner (pod in arc-system namespace)
    ↓
Runner pod has:
  - GitHub token (from secret)
  - kubectl access (from RBAC)
  - NO direct AWS access
```

### 3️⃣ Workflow Creates Terraform Execution Pod

```
ARC runner runs:
  kubectl create pod -f terraform-pod.yaml \
    -n aft-terraform \
    --service-account terraform-sa
    ↓
Terraform pod starts in aft-terraform namespace
```

### 4️⃣ IRSA Injects AWS Credentials

```
Terraform pod starts
    ↓
IRSA webhook (mutating webhook on EKS)
    ↓
Detects terraform-sa service account
    ↓
Reads IRSA annotation:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/TerraformK8sRole
    ↓
Injects environment variables:
  AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/TerraformK8sRole
  AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

### 5️⃣ Terraform Executes

```
terraform plan/apply
    ↓
Detects AWS_ROLE_ARN + AWS_WEB_IDENTITY_TOKEN_FILE
    ↓
Calls AWS STS AssumeRoleWithWebIdentity
    ↓
Gets temporary credentials
    ↓
Executes terraform with those credentials
    ↓
Creates/modifies AWS resources
```

### 6️⃣ Results Posted

```
terraform output
    ↓
Pod exits
    ↓
ARC runner collects results
    ↓
Posts to PR/commit in GitHub
```

---

## Why Only ONE Role?

### ❌ You DO NOT Need GitHubActionsRole

**GitHubActionsRole was for:** GitHub Actions on GitHub.com (hosted runners)

```
GitHub.com hosted runner
    ↓
Assumes GitHubActionsRole (GitHub OIDC)
    ↓
Gets AWS credentials
    ↓
Runs terraform
```

### ✅ You ONLY Need TerraformK8sRole

**TerraformK8sRole is for:** K8s pod execution (your setup)

```
ARC pod (in K8s)
    ↓
Creates terraform pod
    ↓
K8s service account has IRSA annotation
    ↓
IRSA webhook injects credentials for TerraformK8sRole
    ↓
Terraform runs with those credentials
```

**No GitHub OIDC needed because:**
- GitHub Actions doesn't assume AWS role
- K8s service account assumes the role instead
- IRSA handles credential injection automatically

---

## IAM Permissions Breakdown

```
TerraformK8sRole Permissions:
├─ organizations:* (all operations on OUs/accounts)
├─ iam:* (create/manage IAM roles)
├─ s3:GetObject/PutObject/ListBucket (state file access)
└─ s3:GetBucketVersioning (for versioning)
```

---

## State Management

### S3 Locking Flow

```
terraform apply
    ↓
AWS SDK checks for lock file in S3
    ↓
Creates aft/terraform.tfstate.lock file
    ↓
Holds lock for duration of apply
    ↓
Removes lock when apply completes
    ↓
If apply fails → lock remains (manual cleanup needed)
```

### Why S3 (not DynamoDB)?

| Feature | S3 | DynamoDB |
|---------|----|----|
| Reliability | Good (eventual consistency) | Excellent (strong consistency) |
| Cost | Lower | Higher |
| Concurrency Lock | Best effort | Guaranteed |
| Setup | Simpler | Extra resource |
| **Your Use Case** | ✅ Sufficient | ❌ Overkill |

---

## Security Model

### Credential Injection Flow

```
1. Kubernetes detects service account: terraform-sa
                    ↓
2. IRSA webhook runs (mutating webhook)
                    ↓
3. Reads annotation from service account:
   eks.amazonaws.com/role-arn: arn:aws:iam::...
                    ↓
4. Generates OIDC token from K8s service account
                    ↓
5. Injects into pod environment:
   AWS_ROLE_ARN (role to assume)
   AWS_WEB_IDENTITY_TOKEN_FILE (path to token)
                    ↓
6. Pod has NO credentials written to disk
   Pod has NO AWS_ACCESS_KEY_ID
   Pod has NO AWS_SECRET_ACCESS_KEY
                    ↓
7. terraform AWS SDK detects env vars
                    ↓
8. Calls AWS STS AssumeRoleWithWebIdentity
                    ↓
9. Gets temporary credentials (15 min default)
                    ↓
10. Credentials auto-refresh as needed
```

### Why This Is Secure

✅ No credentials stored in pod environment  
✅ No credentials in git history  
✅ No credentials in secrets  
✅ Credentials are temporary (15 min)  
✅ Credentials auto-rotate  
✅ Audit trail via CloudTrail  
✅ Fine-grained IAM controls  

---

## Troubleshooting Checklist

### "Pod can't access AWS"
→ Check IRSA annotation on terraform-sa: `kubectl get sa terraform-sa -n aft-terraform -o yaml | grep role-arn`

### "terraform plan fails"
→ Check pod logs: `kubectl logs -f terraform-pod-name -n aft-terraform`

### "State lock error"
→ Check S3 bucket: `aws s3 ls s3://terraform-state-aft-ACCOUNT_ID/aft/`

### "ARC runner never picks up job"
→ Verify runner is registered: GitHub Settings → Actions → Runners

---

## Key Files

| File | Purpose |
|------|---------|
| `terraform/iam-roles.tf` | Defines TerraformK8sRole only |
| `terraform/backend-infrastructure.tf` | S3 bucket + log bucket |
| `k8s/2-rbac.yaml` | Service account with IRSA annotation |
| `k8s/4-actions-runner-deployment.yaml` | ARC runner pods |
| `.github/workflows/terraform-plan.yml` | Creates terraform execution pod |

---

## Comparison: Your Setup vs Alternatives

### Setup A: GitHub Hosted Runners (NOT YOU)
```
GitHub.com → GitHubActionsRole (OIDC) → AWS
```

### Setup B: Your Setup (K8s with IRSA)
```
ARC in K8s → terraform-sa (IRSA) → TerraformK8sRole → AWS
```

### Setup C: K8s with Stored Credentials (NOT RECOMMENDED)
```
ARC in K8s → Secret with AWS_ACCESS_KEY_ID → AWS
                      ↑
                   Security Risk!
```

**You chose Setup B:** Best of both worlds
- ✅ Self-hosted (no GitHub rate limits)
- ✅ No stored credentials (IRSA magic)
- ✅ Temporary credentials (auto-rotating)
- ✅ Audit trail (CloudTrail logging)

---

## Next Steps

1. Update placeholder values in iam-roles.tf
2. Follow DEPLOYMENT-CHECKLIST.md step-by-step
3. Test complete workflow: code push → plan → apply
4. Monitor CloudTrail for audit trail
