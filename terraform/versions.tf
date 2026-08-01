terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "management"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.management_account_id}:role/OrganizationAccountAccessRole"
  }
}
