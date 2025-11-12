variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_arn" {
  type = string
}

variable "db_password_ssm_param" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

