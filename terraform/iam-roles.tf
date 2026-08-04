# ============================================================
# IAM ROLES FOR AFT DEPLOYMENT
# ============================================================
# Single Role Architecture:
# - ARC runner pods: Use kubectl + GitHub token (no AWS role needed)
# - Terraform execution pod: Uses IRSA to assume TerraformK8sRole
# ============================================================

# Data source: Current AWS Account
data "aws_caller_identity" "current" {}

# ============================================================
# ROLE: Kubernetes IRSA Role (Terraform Execution)
# ============================================================
# Purpose: Allow K8s pods to assume this role via IRSA
# Trust: OIDC tokens from EKS cluster
# Permissions: Terraform execution (Organizations + IAM)

resource "aws_iam_role" "terraform_k8s_role" {
  name               = "TerraformK8sRole"
  assume_role_policy = data.aws_iam_policy_document.terraform_k8s_trust.json

  tags = {
    Name        = "TerraformK8sRole"
    Environment = "kubernetes"
    ManagedBy   = "Terraform"
  }
}

# Trust policy: Allow IRSA (K8s service account) to assume this role
data "aws_iam_policy_document" "terraform_k8s_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.YOUR_AWS_REGION.amazonaws.com/id/YOUR_CLUSTER_ID"]
      # Replace: YOUR_AWS_REGION with your EKS region (e.g., us-east-1)
      # Replace: YOUR_CLUSTER_ID with your EKS cluster ID
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.YOUR_AWS_REGION.amazonaws.com/id/YOUR_CLUSTER_ID:sub"
      values   = ["system:serviceaccount:aft-terraform:terraform-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.YOUR_AWS_REGION.amazonaws.com/id/YOUR_CLUSTER_ID:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Policy: Permissions for Terraform execution
resource "aws_iam_role_policy" "terraform_k8s_policy" {
  name   = "TerraformK8sPolicy"
  role   = aws_iam_role.terraform_k8s_role.id
  policy = data.aws_iam_policy_document.terraform_k8s_permissions.json
}

data "aws_iam_policy_document" "terraform_k8s_permissions" {
  statement {
    sid    = "OrganizationsAccess"
    effect = "Allow"
    actions = [
      "organizations:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMRoleAccess"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:UpdateAssumeRolePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]
    resources = [
      "arn:aws:s3:::terraform-state-aft-*",
      "arn:aws:s3:::terraform-state-aft-*/*"
    ]
  }

  statement {
    sid    = "DynamoDBLocking"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/terraform-lock-*"]
  }
}

# ============================================================
# OUTPUTS - ARNs for Configuration
# ============================================================

output "terraform_k8s_role_arn" {
  description = "Terraform K8s Role ARN (use in k8s/2-rbac.yaml IRSA annotation)"
  value       = aws_iam_role.terraform_k8s_role.arn
}

output "terraform_k8s_role_name" {
  description = "Terraform K8s Role Name"
  value       = aws_iam_role.terraform_k8s_role.name
}

output "current_account_id" {
  description = "Current AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
