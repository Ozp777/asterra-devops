# --------- IAM לתפקיד הרצה ב-Fargate ---------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.project}-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${local.project}-ecs-task-exec-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --------- CloudWatch Logs ---------
resource "aws_cloudwatch_log_group" "mapserver" {
  name              = "/ecs/${local.project}-mapserver"
  retention_in_days = 14
  tags              = { Name = "${local.project}-mapserver-logs" }
}

# --------- ECS Cluster ---------
resource "aws_ecs_cluster" "public" {
  name = "${local.project}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Name = "${local.project}-cluster" }
}

# --------- Task Definition (MapServer) ---------
resource "aws_ecs_task_definition" "mapserver" {
  family                   = "${local.project}-mapserver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "mapserver",
      image     = "camptocamp/mapserver:latest",
      essential = true,
      portMappings = [
        { containerPort = 80, hostPort = 80, protocol = "tcp" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.mapserver.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "mapserver"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = { Name = "${local.project}-mapserver-td" }
}

# --------- SG ל-ALB ציבורי ---------
resource "aws_security_group" "alb_public_sg" {
  name   = "${local.project}-alb-public-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-alb-public-sg" }
}

# --------- SG לשירות ה-ECS (מקבל רק מה-ALB) ---------
resource "aws_security_group" "ecs_service_sg" {
  name   = "${local.project}-ecs-service-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-ecs-service-sg" }
}

# --------- ALB ציבורי ---------
resource "aws_lb" "public" {
  name               = "${local.project}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_public_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]
  tags               = { Name = "${local.project}-alb" }
}

resource "aws_lb_target_group" "mapserver_tg" {
  name        = "${local.project}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${local.project}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mapserver_tg.arn
  }
}

# --------- ECS Service ---------
resource "aws_ecs_service" "mapserver" {
  name            = "${local.project}-mapserver-svc"
  cluster         = aws_ecs_cluster.public.id
  task_definition = aws_ecs_task_definition.mapserver.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id, aws_subnet.public2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_service_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mapserver_tg.arn
    container_name   = "mapserver"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
  tags       = { Name = "${local.project}-mapserver-svc" }
}

# --------- Outputs ---------
output "mapserver_alb_dns" {
  value = aws_lb.public.dns_name
}

