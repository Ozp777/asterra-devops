resource "aws_security_group" "efs" {
  name        = "${local.name}-efs-sg"
  description = "Allow NFS 2049 from ECS tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-efs-sg" }
}

resource "aws_efs_file_system" "wp" {
  creation_token = "${local.name}-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${local.name}-efs" }
}

resource "aws_efs_mount_target" "wp" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]

  depends_on = [aws_efs_file_system.wp]
}

