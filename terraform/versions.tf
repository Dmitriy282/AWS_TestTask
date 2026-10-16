terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = { # the public IP of this machine for the SSH rule
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    local = { # the Ansible inventory file
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "AWS_TestTask"
      ManagedBy = "terraform"
    }
  }
}
