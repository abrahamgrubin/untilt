terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # S3-native state locking (Terraform 1.10+, conditional writes) — no
  # DynamoDB table needed. If you're on an older Terraform, use
  # `dynamodb_table = "untilt-terraform-locks"` instead of `use_lockfile`.
  backend "s3" {
    bucket       = "untilt-terraform-state-710976282506"
    key          = "untilt/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
