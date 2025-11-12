########################################
# Random suffix לשמות באקטים
########################################
resource "random_id" "suffix" {
  byte_length = 3
}

########################################
# S3 – באקט פרטי ל-ingest (GeoJSON)
########################################
resource "aws_s3_bucket" "data_private" {
  bucket = "${local.project}-data-private-${random_id.suffix.hex}"
  tags   = { Name = "${local.project}-data-private" }
}

resource "aws_s3_bucket_public_access_block" "data_private" {
  bucket                  = aws_s3_bucket.data_private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

########################################
# S3 – באקט ציבורי ל-Half-Pager (Website)
########################################
resource "aws_s3_bucket" "halfpager_public" {
  bucket = "${local.project}-halfpager-${random_id.suffix.hex}"
  tags   = { Name = "${local.project}-halfpager" }
}

resource "aws_s3_bucket_public_access_block" "halfpager_public" {
  bucket                  = aws_s3_bucket.halfpager_public.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "halfpager_public" {
  bucket = aws_s3_bucket.halfpager_public.id
  index_document { suffix = "index.html" }
}

data "aws_iam_policy_document" "halfpager_public_read" {
  statement {
    sid     = "AllowPublicRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.halfpager_public.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "halfpager_public" {
  bucket = aws_s3_bucket.halfpager_public.id
  policy = data.aws_iam_policy_document.halfpager_public_read.json
}

########################################
# VPC Endpoint ל-S3 (Gateway) – למשאבים פרטיים בלי NAT
########################################
data "aws_route_tables" "this_vpc" {
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.this_vpc.ids
  tags              = { Name = "${local.project}-s3-endpoint" }
}

########################################
# Outputs
########################################
output "s3_data_private_bucket" {
  value = aws_s3_bucket.data_private.bucket
}

output "s3_halfpager_public_bucket" {
  value = aws_s3_bucket.halfpager_public.bucket
}

output "s3_halfpager_public_website_url" {
  value = "http://${aws_s3_bucket.halfpager_public.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}

