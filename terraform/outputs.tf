output "production_ou_id" {
  description = "Production Organizational Unit ID"
  value       = aws_organizations_organizational_unit.production.id
}

output "staging_ou_id" {
  description = "Staging Organizational Unit ID"
  value       = aws_organizations_organizational_unit.staging.id
}

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

output "account_mapping" {
  description = "Account ID to Name mapping"
  value = {
    for name, account in aws_organizations_account.accounts : account.id => name
  }
}

output "production_accounts" {
  description = "Production environment accounts"
  value = {
    for name, account in aws_organizations_account.accounts :
    name => account.id
    if var.accounts[name].environment == "prod"
  }
}

output "staging_accounts" {
  description = "Staging environment accounts"
  value = {
    for name, account in aws_organizations_account.accounts :
    name => account.id
    if var.accounts[name].environment == "staging"
  }
}
