terraform {
  # 1.11: ephemeral resources + write-only attributes — the secrets are written to Vault, never to the state
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    vault = { # the secrets: SSH key and the passwords of the stack
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    tls = { # generates the SSH key
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    random = { # generates the passwords
      source  = "hashicorp/random"
      version = "~> 3.7"
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

# Token from VAULT_TOKEN (vault/.vault-token, see vault/bootstrap.sh)
provider "vault" {
  address = var.vault_addr
}
