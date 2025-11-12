resource "random_password" "db_password" {
  length  = 20
  special = true
}

resource "aws_ssm_parameter" "db_password" {
  name      = var.db_password_ssm_param
  type      = "SecureString"
  value     = random_password.db_password.result
  overwrite = true
}

