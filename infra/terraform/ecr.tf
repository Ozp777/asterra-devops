########################################
# ECR repository for the loader image
########################################
resource "aws_ecr_repository" "loader" {
  name                 = "${local.project}/loader"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${local.project}-ecr-loader" }
}

data "aws_caller_identity" "current" {}
locals {
  ecr_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# תווית גרסה לתמונה (נקבע מבחוץ דרך -var או tfvars)
variable "image_tag" {
  type    = string
  default = "v0.1.0"
}

output "ecr_repo_uri" {
  value = "${local.ecr_uri}/${aws_ecr_repository.loader.name}"
}

