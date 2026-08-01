# Get the root OU
data "aws_organizations_organization" "root" {
  provider = aws.management
}

# Create Production OU
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

# Create Staging OU
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

# Create AWS accounts
resource "aws_organizations_account" "accounts" {
  for_each = var.accounts

  provider = aws.management

  name              = each.key
  email             = each.value.email
  iam_user_access_to_billing = "ALLOW"
  close_on_deletion = false

  tags = {
    Name        = each.key
    Project     = each.value.project
    Environment = each.value.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [email]
  }

  depends_on = [
    aws_organizations_organizational_unit.production,
    aws_organizations_organizational_unit.staging
  ]
}

# Move Production accounts to Production OU
resource "aws_organizations_organizational_unit_parent" "prod_accounts" {
  for_each = {
    for name, account in var.accounts : name => account
    if account.environment == "prod"
  }

  provider          = aws.management
  account_id        = aws_organizations_account.accounts[each.key].id
  parent_id         = aws_organizations_organizational_unit.production.id

  depends_on = [aws_organizations_account.accounts]
}

# Move Staging accounts to Staging OU
resource "aws_organizations_organizational_unit_parent" "staging_accounts" {
  for_each = {
    for name, account in var.accounts : name => account
    if account.environment == "staging"
  }

  provider          = aws.management
  account_id        = aws_organizations_account.accounts[each.key].id
  parent_id         = aws_organizations_organizational_unit.staging.id

  depends_on = [aws_organizations_account.accounts]
}
