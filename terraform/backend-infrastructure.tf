# ============================================================
# TERRAFORM STATE BACKEND - S3 + DynamoDB
# ============================================================

# ============================================================
# S3 BUCKET FOR TERRAFORM STATE
# ============================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-aft-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State - AFT"
    Environment = "management"
    ManagedBy   = "Terraform"
  }
}

# Enable versioning (recover from accidental deletions)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"  # Set to "Enabled" if MFA required
  }
}

# Enable encryption (protect sensitive data)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access (security best practice)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging (audit trail)
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-logs/"
}

# ============================================================
# S3 BUCKET FOR LOGS
# ============================================================

resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "terraform-state-logs-aft-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Logs - AFT"
    Environment = "management"
    ManagedBy   = "Terraform"
  }
}

# Block public access for logs bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# OUTPUTS - Backend Configuration
# ============================================================
# Note: S3 state locking is used instead of DynamoDB for simplicity
# (S3 locking is sufficient for single management account)

output "s3_bucket_name" {
  description = "S3 bucket for terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "backend_config" {
  description = "Backend configuration for backend.tf"
  value = {
    bucket  = aws_s3_bucket.terraform_state.id
    key     = "aft/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
