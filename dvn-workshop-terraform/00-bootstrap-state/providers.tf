terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Este stack usa state LOCAL de propósito: é o bootstrap da infraestrutura de state
  # remoto — não pode depender de si mesmo (dependência circular). Nunca migrar este
  # backend para S3.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = var.tags.managed_by
      Owner       = var.owner
      ADR         = "ADR-002"
    }
  }
}
