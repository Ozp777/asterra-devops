# SG ל-ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-tasks-sg"
  description = "ECS tasks (WordPress) to ALB/EFS/DB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-tasks-sg" }
}

# לאפשר HTTP מ-ALB ל-ECS
resource "aws_security_group_rule" "tasks_ingress_from_alb" {
  for_each                 = toset(data.aws_lb.public.security_groups)
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = each.value
}

# יציאה החוצה
resource "aws_security_group_rule" "tasks_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.ecs_tasks.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# לפתוח ל-DB ו-EFS מ-ECS
resource "aws_security_group_rule" "db_ingress_from_tasks" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "efs_ingress_from_tasks" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

# Cluster חדש
resource "aws_ecs_cluster" "wp" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name}-cluster" }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "wp" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14
}

# Roles למשימה
resource "aws_iam_role" "task_execution" {
  name = "${local.name}-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# הרשאת קריאה ל-SSM + KMS decrypt
resource "aws_iam_policy" "ssm_read" {
  name        = "${local.name}-ssm-read"
  description = "Allow read SecureString for WP DB password"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory",
        "kms:Decrypt"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_read_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

# Target Group ל-WP
resource "aws_lb_target_group" "wp" {
  name        = "${local.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = { Name = "${local.name}-tg" }
}

# Task Definition עם EFS ל-wp-content
resource "aws_ecs_task_definition" "wp" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_execution.arn

  volume {
    name = "wpcontent"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wp.id
      transit_encryption = "ENABLED"
      root_directory     = "/"
    }
  }

  container_definitions = jsonencode([
    {
      name         = "wordpress",
      image        = "wordpress:6.6-php8.2-apache",
      essential    = true,
      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }],
      environment = [
        { name = "WORDPRESS_DB_NAME", value = "wordpress" },
        { name = "WORDPRESS_DB_USER", value = "wpuser" },
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wp.address }
      ],
      secrets = [
        { name = "WORDPRESS_DB_PASSWORD", valueFrom = var.db_password_ssm_param }
      ],
      mountPoints = [
        { sourceVolume = "wpcontent", containerPath = "/var/www/html/wp-content", readOnly = false }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.wp.name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${local.name}-task" }
}

# Service
resource "aws_ecs_service" "wp" {
  name            = "${local.name}-svc"
  cluster         = aws_ecs_cluster.wp.id
  task_definition = aws_ecs_task_definition.wp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wp.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_db_instance.wp,
    aws_efs_mount_target.wp
  ]

  tags = { Name = "${local.name}-svc" }
}

