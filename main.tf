########################################
# Terraform Providers & Settings
########################################
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

########################################
# AWS Provider Configuration
########################################
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

########################################
# Locals
########################################
locals {
  project = var.project_name
}

########################################
# Backend (optional)
########################################
# אם תרצה לשמור state ב-S3 במקום מקומי:
# terraform {
#   backend "s3" {
#     bucket         = "asterra-terraform-state"
#     key            = "infra/terraform.tfstate"
#     region         = "us-east-1"
#     profile        = "asterra"
#     encrypt        = true
#   }
# }

########################################
# Outputs Summary (לנוחות)
########################################
output "summary" {
  value = {
    region                     = var.aws_region
    profile                    = var.aws_profile
    project_name               = var.project_name
    vpc_id                     = aws_vpc.main.id
    public_subnet_id           = aws_subnet.public.id
    private_subnet_ids         = [aws_subnet.private1.id, aws_subnet.private2.id]
    rds_endpoint               = aws_db_instance.pg.address
    rds_port                   = aws_db_instance.pg.port
    s3_data_private_bucket     = aws_s3_bucket.data_private.bucket
    s3_halfpager_public_bucket = aws_s3_bucket.halfpager_public.bucket
    s3_halfpager_website_url   = "http://${aws_s3_bucket.halfpager_public.bucket}.s3-website-${var.aws_region}.amazonaws.com"
    lambda_loader_role_arn     = aws_iam_role.lambda_loader_role.arn
  }
  description = "Quick summary of key resources created by Terraform."
}

