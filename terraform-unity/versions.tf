terraform {
  required_version = "~> 1.8.2"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}
