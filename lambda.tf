########################################
# Security Group for Lambda ENI
########################################
resource "aws_security_group" "lambda_sg" {
  name        = "${local.project}-lambda-sg"
  description = "Lambda ENI egress"
  vpc_id      = aws_vpc.main.id

  # אין צורך ב-ingress (Lambda יוזם חיבורים החוצה)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-lambda-sg" }
}

########################################
# Lambda (container image)
########################################
# image URI יורכב מה-ECR + תגית
locals {
  loader_image_uri = "${local.ecr_uri}/${aws_ecr_repository.loader.name}:${var.image_tag}"
}

resource "aws_lambda_function" "geojson_loader" {
  function_name = "${local.project}-geojson-loader"
  package_type  = "Image"
  image_uri     = local.loader_image_uri
  role          = aws_iam_role.lambda_loader_role.arn

  timeout       = 120
  memory_size   = 1024
  architectures = ["x86_64"]

  vpc_config {
    subnet_ids         = [aws_subnet.private1.id, aws_subnet.private2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.pg.address
      DB_PORT = tostring(aws_db_instance.pg.port)
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  }

  depends_on = [
    aws_iam_role.lambda_loader_role,
    aws_vpc_endpoint.s3_gateway # כדי לוודא גישה ל-S3 מתוך VPC
  ]

  tags = { Name = "${local.project}-lambda" }
}

########################################
# Allow S3 bucket to invoke the Lambda
########################################
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geojson_loader.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_private.arn
}

########################################
# S3 -> Lambda notification on *.geojson
########################################
resource "aws_s3_bucket_notification" "data_private" {
  bucket = aws_s3_bucket.data_private.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.geojson_loader.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".geojson"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

output "lambda_name" { value = aws_lambda_function.geojson_loader.function_name }
output "lambda_image_uri" { value = local.loader_image_uri }

