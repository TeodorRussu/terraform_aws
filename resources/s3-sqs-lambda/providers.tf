# CONFIGURE TERRAFORM PROVIDER
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.71.0"
    }
  }
}

# CONFIGURE OUR AWS CONNECTION
provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  region                  = "eu-west-1"
  profile                 = "dev"
}