########################################
# IAM Role ל-Lambda Loader
########################################
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_loader_role" {
  name               = "${local.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = { Name = "${local.project}-lambda-role" }
}

# Policies מנוהלות בסיסיות ל-Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_loader_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_loader_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

########################################
# Inline policy – הרשאות מינימליות ל-S3 ingest bucket
########################################
data "aws_iam_policy_document" "lambda_s3_read" {
  statement {
    sid     = "ReadIngestBucket"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.data_private.arn,
      "${aws_s3_bucket.data_private.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_s3_read" {
  name   = "${local.project}-lambda-s3"
  role   = aws_iam_role.lambda_loader_role.id
  policy = data.aws_iam_policy_document.lambda_s3_read.json
}

########################################
# Outputs
########################################
output "lambda_loader_role_name" {
  value = aws_iam_role.lambda_loader_role.name
}

output "lambda_loader_role_arn" {
  value = aws_iam_role.lambda_loader_role.arn
}

