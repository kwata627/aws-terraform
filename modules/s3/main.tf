# ----- S3バケットの作成（静的ファイル・ログ保存用） -----

# --- S3バケットの作成 ---
resource "aws_s3_bucket" "main" {
  bucket = "${var.project}-static-files-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project}-static-files"
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

# --- ランダム文字列の生成（バケット名の重複回避用） ---
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}


