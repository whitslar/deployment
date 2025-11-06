terraform {
  required_version = ">= 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Optional: Configure backend for state storage
  # Uncomment and configure for production use
  backend "s3" {
    bucket         = "rvmp-terraform-state"
    key            = "kerberos-microk8s/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = false
    use_lockfile   = true
  }
}