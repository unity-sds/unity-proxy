terraform {
  required_version = "~> 1.8.2"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.47.0"
    }
  }
}
