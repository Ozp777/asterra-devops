# מאתרים את ה-Listener הקיים על פורט 80 לפי ה-ALB ARN
data "aws_lb_listener" "http_80" {
  load_balancer_arn = var.alb_arn
  port              = 80
}

# כלל שמפנה כל בקשה לנתיב /wp* או /wordpress* אל ה-Target Group של WP
resource "aws_lb_listener_rule" "wp_path_rule" {
  listener_arn = data.aws_lb_listener.http_80.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp.arn
  }

  condition {
    path_pattern {
      values = ["/wp*", "/wordpress*"]
    }
  }

  tags = {
    Name = "${local.project}-wp-path-rule"
  }
}

