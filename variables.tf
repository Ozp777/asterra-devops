# ===== AWS =====
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "asterra"
}

# ===== Project =====
variable "project_name" {
  type    = string
  default = "asterra-demo"
}

variable "my_ip" {
  type    = string
  default = "77.125.229.223/32"
}

# ===== Networking =====
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "private_subnet1_cidr" {
  type    = string
  default = "10.20.2.0/24"
}

variable "private_subnet2_cidr" {
  type    = string
  default = "10.20.3.0/24"
}

# ===== Database =====
variable "db_name" {
  type    = string
  default = "asterra"
}

variable "db_username" {
  type    = string
  default = "asterra_admin"
}

# נזין סיסמה דרך משתנה סביבה: export TF_VAR_db_password='...'
variable "db_password" {
  type = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}


variable "public_domain" {
  description = "FQDN ל-ALB הציבורי (למשל maps.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Hosted Zone ID אם הדומיין מנוהל ב-Route53 (לא חובה)"
  type        = string
  default     = ""
}

