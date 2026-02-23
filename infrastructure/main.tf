terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
  }
  required_version = "~> 1.14"
}

provider "aws" {
    region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = var.acm_region
}



data "aws_caller_identity" "current" {}