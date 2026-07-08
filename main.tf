terraform {
  # it is not possible to use variables for terraform backend so you have to replace this placeholders
  backend "s3" {
    bucket = "terraform-<account>-<region>-an"
    key = "talos-aws"
    region = "<region>"
  }
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}