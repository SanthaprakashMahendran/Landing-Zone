# ============================================================
# SCP 1: BASIC - Deny Unauthorized Regions (Understanding Flow)
# ============================================================
# This policy restricts all AWS API calls to specific regions only
# Applies to: Both Production and Staging OUs

resource "aws_organizations_policy" "deny_unauthorized_regions" {
  name        = "DenyUnauthorizedRegions"
  description = "Restricts AWS API calls to approved regions only (us-east-1, us-west-2)"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnauthorizedRegions"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "organizations:*",
          "route53:*",
          "support:*",
          "cloudfront:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "us-west-2"
            ]
          }
        }
      }
    ]
  })
}

# ============================================================
# SCP 2: CUSTOM - Deny Untagged Resources (Both Prod & Staging)
# ============================================================
# This policy DENIES creation of resources without required tags
# Required tags: Primary, Secondary, Service
# Applies to: Both Production and Staging OUs

resource "aws_organizations_policy" "deny_untagged_resources" {
  name        = "DenyUntaggedResources"
  description = "Denies creation of EC2, S3, RDS, Lambda resources without required tags (Primary, Secondary, Service)"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyEC2UntaggedResources"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "ec2:CreateSecurityGroup",
          "ec2:CreateNetworkInterface"
        ]
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:network-interface/*"
        ]
        Condition = {
          StringNotLike = {
            "aws:RequestTag/Primary"   = "?*"
            "aws:RequestTag/Secondary" = "?*"
            "aws:RequestTag/Service"   = "?*"
          }
        }
      },
      {
        Sid    = "DenyS3UntaggedResources"
        Effect = "Deny"
        Action = [
          "s3:CreateBucket",
          "s3:PutObject"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-tagging" = "Primary=*&Secondary=*&Service=*"
          }
        }
      },
      {
        Sid    = "DenyRDSUntaggedResources"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:CreateDBCluster",
          "rds:CreateDBParameterGroup"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:RequestTag/Primary"   = "?*"
            "aws:RequestTag/Secondary" = "?*"
            "aws:RequestTag/Service"   = "?*"
          }
        }
      },
      {
        Sid    = "DenyLambdaUntaggedResources"
        Effect = "Deny"
        Action = [
          "lambda:CreateFunction"
        ]
        Resource = "arn:aws:lambda:*:*:function/*"
        Condition = {
          StringNotLike = {
            "aws:RequestTag/Primary"   = "?*"
            "aws:RequestTag/Secondary" = "?*"
            "aws:RequestTag/Service"   = "?*"
          }
        }
      }
    ]
  })
}

# ============================================================
# SCP 3: PRODUCTION-SPECIFIC - Deny Public S3 (Prod Only)
# ============================================================
# This policy DENIES making S3 buckets public in production
# Applies to: Production OU ONLY (not staging)

resource "aws_organizations_policy" "deny_public_s3_production" {
  name        = "DenyPublicS3Production"
  description = "Production-only: Denies making S3 buckets public (Block Public Access must be enabled)"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyS3PublicACL"
        Effect = "Deny"
        Action = [
          "s3:PutAccountPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      },
      {
        Sid    = "DenyS3BucketPolicy"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================
# ATTACH SCPs TO OUS
# ============================================================

# Attach Basic SCP (Deny Unauthorized Regions) to BOTH Prod and Staging
resource "aws_organizations_policy_attachment" "deny_regions_prod" {
  policy_id = aws_organizations_policy.deny_unauthorized_regions.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "deny_regions_staging" {
  policy_id = aws_organizations_policy.deny_unauthorized_regions.id
  target_id = aws_organizations_organizational_unit.staging.id
}

# Attach Custom SCP (Deny Untagged Resources) to BOTH Prod and Staging
resource "aws_organizations_policy_attachment" "deny_untagged_prod" {
  policy_id = aws_organizations_policy.deny_untagged_resources.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "deny_untagged_staging" {
  policy_id = aws_organizations_policy.deny_untagged_resources.id
  target_id = aws_organizations_organizational_unit.staging.id
}

# Attach Production-Specific SCP (Deny Public S3) to PRODUCTION OU ONLY
resource "aws_organizations_policy_attachment" "deny_public_s3_prod_only" {
  policy_id = aws_organizations_policy.deny_public_s3_production.id
  target_id = aws_organizations_organizational_unit.production.id
}

# ============================================================
# OUTPUTS - View Created SCPs
# ============================================================

output "scp_basic_id" {
  description = "SCP 1: DenyUnauthorizedRegions Policy ID"
  value       = aws_organizations_policy.deny_unauthorized_regions.id
}

output "scp_custom_id" {
  description = "SCP 2: DenyUntaggedResources Policy ID"
  value       = aws_organizations_policy.deny_untagged_resources.id
}

output "scp_prod_id" {
  description = "SCP 3: DenyPublicS3Production Policy ID"
  value       = aws_organizations_policy.deny_public_s3_production.id
}

output "scp_attachments" {
  description = "SCP Attachments to OUs"
  value = {
    production_ou = {
      "DenyUnauthorizedRegions" = "Basic SCP"
      "DenyUntaggedResources"   = "Custom SCP (tags required)"
      "DenyPublicS3Production"  = "Prod-Only SCP"
    }
    staging_ou = {
      "DenyUnauthorizedRegions" = "Basic SCP"
      "DenyUntaggedResources"   = "Custom SCP (tags required)"
    }
  }
}
