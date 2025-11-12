# נשתמש ב-role של task execution שכבר קיים (ecs_task_execution_role) מהקובץ הציבורי.
# אם אין — העתק את ה-IAM מהקובץ הציבורי או ניצור חדש.

resource "aws_cloudwatch_log_group" "geoprocessor" {
  name              = "/ecs/${local.project}-geoprocessor"
  retention_in_days = 14
  tags              = { Name = "${local.project}-geoprocessor-logs" }
}

# Task Definition
variable "geoproc_image" {
  type        = string
  description = "Full ECR image URI for geoprocessor"
}

resource "aws_ecs_task_definition" "geoprocessor" {
  family                   = "${local.project}-geoprocessor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "geoprocessor",
      image     = var.geoproc_image,
      essential = true,
      portMappings = [
        { containerPort = 80, hostPort = 80, protocol = "tcp" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.geoprocessor.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "geoprocessor"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = { Name = "${local.project}-geoprocessor-td" }
}

# SG ל-ALB פנימי (נגיש רק בתוך ה-VPC)
resource "aws_security_group" "alb_internal_sg" {
  name   = "${local.project}-alb-internal-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from VPC only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-alb-internal-sg" }
}

# ALB פנימי (בפרטיים)
resource "aws_lb" "internal" {
  name               = "${local.project}-alb-internal"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb_internal_sg.id]
  subnets            = [aws_subnet.private1.id, aws_subnet.private2.id]
  tags               = { Name = "${local.project}-alb-internal" }
}

resource "aws_lb_target_group" "geoproc_tg" {
  name        = "${local.project}-geoproc-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${local.project}-geoproc-tg" }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.geoproc_tg.arn
  }
}

# SG לשירות ה-ECS (מקבל רק מה-ALB הפנימי)
resource "aws_security_group" "ecs_private_sg" {
  name   = "${local.project}-ecs-private-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "from internal ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-ecs-private-sg" }
}

# ECS Service (בפרטיים, בלי public IP)
resource "aws_ecs_service" "geoprocessor" {
  name            = "${local.project}-geoprocessor-svc"
  cluster         = aws_ecs_cluster.public.id
  task_definition = aws_ecs_task_definition.geoprocessor.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private1.id, aws_subnet.private2.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_private_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.geoproc_tg.arn
    container_name   = "geoprocessor"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.internal_http]
  tags       = { Name = "${local.project}-geoprocessor-svc" }
}

# Outputs
output "geoprocessor_alb_internal_dns" {
  value = aws_lb.internal.dns_name
}

