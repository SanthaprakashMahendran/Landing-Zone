# AWS AFT (Account Factory for Terraform) Setup

This directory contains Terraform configurations for AWS account provisioning with AWS Control Tower and organizational structure.

## Architecture Overview

```
Management Account
├── Control Tower
├── Landing Zone (us-east-1)
└── Organization
    ├── Security OU (log & audit account)
    ├── Production OU
    │   ├── freshdesk-prod
    │   ├── freshservice-prod
    │   └── freshsales-prod
    └── Staging OU
        ├── freshdesk-staging
        ├── freshservice-staging
        └── freshsales-staging
```

## Accounts Being Created

| Account Name | Project | Environment | Email |
|---|---|---|---|
| freshdesk-prod | freshdesk | prod | aws+freshdesk-prod@freshworks.com |
| freshdesk-staging | freshdesk | staging | aws+freshdesk-staging@freshworks.com |
| freshservice-prod | freshservice | prod | aws+freshservice-prod@freshworks.com |
| freshservice-staging | freshservice | staging | aws+freshservice-staging@freshworks.com |
| freshsales-prod | freshsales | prod | aws+freshsales-prod@freshworks.com |
| freshsales-staging | freshsales | staging | aws+freshsales-staging@freshworks.com |

## Prerequisites

1. **AWS Control Tower** - Already enabled with landing zone in us-east-1
2. **Terraform** - Version 1.0 or higher
3. **AWS CLI** - Configured with management account credentials
4. **IAM Permissions** - Sufficient permissions in management account to:
   - Create organizations
   - Create organizational units
   - Create AWS accounts
   - Manage IAM roles

## File Structure

```
terraform/
├── versions.tf           # Provider configuration
├── variables.tf          # Variable definitions
├── main.tf              # Main AFT configuration (OUs & accounts)
├── outputs.tf           # Output values
└── terraform.tfvars     # Variable values (CUSTOMIZE THIS)
```

## Setup Instructions

### Step 1: Update terraform.tfvars

Edit `terraform/terraform.tfvars` with your actual AWS account details:

```hcl
aws_region             = "us-east-1"
management_account_id  = "YOUR_MANAGEMENT_ACCOUNT_ID"  # e.g., 123456789012
control_tower_root_ou_id = "YOUR_ROOT_OU_ID"          # e.g., r-xxxx
```

**How to find these values:**
- Management Account ID: Check AWS Console or `aws sts get-caller-identity`
- Root OU ID: AWS Organizations console → OUs → Root → ID field

### Step 2: Update Email Addresses (Optional)

If you want different email addresses for the accounts, update the `accounts` variable in `terraform/variables.tf`. Note: Each AWS account requires a unique email address.

### Step 3: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 4: Review the Plan

```bash
terraform plan
```

This will show all the resources that will be created:
- 2 OUs (Production & Staging)
- 6 AWS accounts
- Organizational unit parent assignments

### Step 5: Apply Configuration

```bash
terraform apply
```

Review the plan output and type `yes` to confirm.

## Account Access

After accounts are created:

1. **Initial Access**: 
   - AWS sends emails to the specified email addresses
   - Use the OrganizationAccountAccessRole to access accounts

2. **Cross-Account Access**:
   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::ACCOUNT_ID:role/OrganizationAccountAccessRole \
     --role-session-name my-session
   ```

3. **Set up Individual Account Access**:
   - Create IAM users/roles in each account
   - Set up SSO with AWS Identity Center (recommended)

## Outputs

After successful `terraform apply`, you'll see:

```
production_ou_id = "ou-xxxx-xxxxxxxx"
staging_ou_id = "ou-yyyy-yyyyyyyy"
created_accounts = {
  "freshdesk-prod" = {
    id          = "111111111111"
    email       = "aws+freshdesk-prod@freshworks.com"
    environment = "prod"
    project     = "freshdesk"
    ...
  }
  ...
}
```

## Next Steps

### 1. Enroll Accounts in Control Tower

```bash
aws organizations describe-account --account-id ACCOUNT_ID
```

Then use Control Tower console to enroll accounts in the appropriate OU.

### 2. Apply Control Tower Guardrails

- Navigate to Control Tower console
- Select OUs and enable guardrails (mandatory, strongly recommended, etc.)
- Guardrails will be applied to all accounts in that OU

### 3. Set Up AWS Identity Center (Recommended)

```bash
# Enable AWS Identity Center
aws identitystore describe-user-pool --region us-east-1

# Create users and group assignments
# Grant permission sets to accounts
```

### 4. Configure Account Settings

For each account created, you may want to:

- Enable CloudTrail logging to the audit account
- Set up budget alerts
- Enable AWS Config
- Configure VPC and networking
- Set up tagging policies

## Terraform State Management

⚠️ **Important**: Terraform state contains sensitive information.

1. **Store state remotely** (recommended):
   ```bash
   # Create S3 backend
   aws s3 mb s3://terraform-state-aft-freshworks
   aws s3api put-bucket-versioning \
     --bucket terraform-state-aft-freshworks \
     --versioning-configuration Status=Enabled
   ```

2. **Add backend configuration** to `terraform/main.tf`:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "terraform-state-aft-freshworks"
       key            = "aft/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "terraform-lock"
     }
   }
   ```

3. **Create DynamoDB lock table**:
   ```bash
   aws dynamodb create-table \
     --table-name terraform-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
   ```

## Troubleshooting

### Account Creation Fails

- **Error: Invalid email** - Ensure email is unique across all AWS accounts
- **Error: Access Denied** - Verify IAM permissions for OrganizationAccountAccessRole

### OU Parent Assignment Fails

- Wait for accounts to be fully created (may take a few minutes)
- Run `terraform apply` again

### Terraform State Lock

If you get a lock error:
```bash
terraform force-unlock LOCK_ID
```

## Monitoring & Maintenance

### View Accounts in Organization

```bash
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email,Status:Status}'
```

### Check OU Structure

```bash
aws organizations list-organizational-units-for-parent --parent-id r-xxxx
```

### View Account Parent

```bash
aws organizations list-parents --child-id ACCOUNT_ID
```

## Cleanup (Destructive)

To remove all resources created by this Terraform configuration:

```bash
cd terraform
terraform destroy
```

⚠️ This will:
- Delete organizational units
- Close AWS accounts
- Remove all associated resources

## Support & Documentation

- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
- [AWS Control Tower Documentation](https://docs.aws.amazon.com/controltower/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS AFT Documentation](https://aws-samples.github.io/aws-aft-governance-framework/)

## Security Best Practices

1. ✅ Use temporary credentials from IAM roles
2. ✅ Enable MFA for management account
3. ✅ Store Terraform state in encrypted S3 bucket
4. ✅ Use Terraform state locking with DynamoDB
5. ✅ Enable CloudTrail logging
6. ✅ Implement SCPs (Service Control Policies) in OUs
7. ✅ Regularly rotate credentials
8. ✅ Use AWS Identity Center for SSO access

## Cost Estimation

- AWS Organizations: Free
- Control Tower: Free (landing zone setup ~$10-50)
- AWS Accounts: Free to create, cost depends on resources used
- Terraform State Storage: ~$1/month (S3 + DynamoDB)
