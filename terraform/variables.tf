variable "aws_region" {
  description = "AWS region for AFT deployment"
  type        = string
  default     = "us-east-1"
}

variable "management_account_id" {
  description = "AWS Management Account ID"
  type        = string
}

variable "control_tower_root_ou_id" {
  description = "Control Tower Root OU ID"
  type        = string
}

variable "ou_names" {
  description = "Organization Unit names to create"
  type        = list(string)
  default     = ["Production", "Staging"]
}

variable "accounts" {
  description = "AWS accounts to create with their properties"
  type = map(object({
    email       = string
    project     = string
    environment = string
  }))
  default = {
    "freshdesk-prod" = {
      email       = "aws+freshdesk-prod@freshworks.com"
      project     = "freshdesk"
      environment = "prod"
    }
    "freshdesk-staging" = {
      email       = "aws+freshdesk-staging@freshworks.com"
      project     = "freshdesk"
      environment = "staging"
    }
    "freshservice-prod" = {
      email       = "aws+freshservice-prod@freshworks.com"
      project     = "freshservice"
      environment = "prod"
    }
    "freshservice-staging" = {
      email       = "aws+freshservice-staging@freshworks.com"
      project     = "freshservice"
      environment = "staging"
    }
    "freshsales-prod" = {
      email       = "aws+freshsales-prod@freshworks.com"
      project     = "freshsales"
      environment = "prod"
    }
    "freshsales-staging" = {
      email       = "aws+freshsales-staging@freshworks.com"
      project     = "freshsales"
      environment = "staging"
    }
  }
}
