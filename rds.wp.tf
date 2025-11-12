resource "aws_db_subnet_group" "wp" {
  name       = "${local.name}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name}-db-subnet" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "Allow MySQL from ECS tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-db-sg" }
}

resource "aws_db_instance" "wp" {
  identifier             = "${local.name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  db_subnet_group_name   = aws_db_subnet_group.wp.name
  vpc_security_group_ids = [aws_security_group.db.id]

  db_name  = "wordpress"
  username = "wpuser"
  password = aws_ssm_parameter.db_password.value

  skip_final_snapshot = true
  apply_immediately   = true
  deletion_protection = false
  tags                = { Name = "${local.name}-db" }
}

