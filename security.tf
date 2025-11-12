resource "aws_security_group" "rds_sg" {
  name        = "${local.project}-rds-sg"
  description = "Allow Postgres from inside VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from inside VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [description]
  }

  tags = {
    Name = "${local.project}-rds-sg"
  }
}

