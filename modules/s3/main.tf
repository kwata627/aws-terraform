# ----- S3バケットの作成（静的ファイル・ログ保存用） -----

# --- S3バケットの作成 ---
resource "aws_s3_bucket" "main" {
  bucket = "${var.s3_bucket_name}-${random_string.bucket_suffix.result}"

  tags = {
    Name = var.s3_bucket_name
  }
}

# --- バケットバージョニングの設定 ---
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- バケットの暗号化設定 ---
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- バケットのパブリックアクセスブロック設定 ---
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- CloudFront OAC用バケットポリシー ---
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly",
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.main.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.main]
}

# --- ランダム文字列の生成（バケット名の重複回避用） ---
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}


