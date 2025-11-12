# שולף מידע על ה-ALB הקיים לפי ה-ARN שהוזן ב-variables
data "aws_lb" "public" {
  arn = var.alb_arn
}

