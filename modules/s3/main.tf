# =============================================================================
# S3 Module - Main Configuration
# =============================================================================
# 
# このモジュールはAWS S3バケットを作成し、静的ファイルとログの保存を
# 提供します。セキュリティ強化と監視機能を考慮した設計となっています。
#
# 特徴:
# - セキュリティ強化されたS3バケット設定
# - 自動ライフサイクル管理
# - アクセスログとメトリクス
# - CloudFront統合
# - 詳細なタグ管理
# =============================================================================

# -----------------------------------------------------------------------------
# Required Providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # 共通タグ
  common_tags = merge(
    {
      Name        = "${var.project}-s3"
      Environment = var.environment
      Module      = "s3"
      ManagedBy   = "terraform"
      Project     = var.project
      Purpose     = var.bucket_purpose
    },
    var.tags
  )
  
  # バケット名の正規化
  normalized_bucket_name = lower(var.bucket_name)
  
  # リソース名の生成
  resource_names = {
    bucket = "${var.project}-${local.normalized_bucket_name}"
    access_logs = "${var.project}-${local.normalized_bucket_name}-access-logs"
    inventory = "${var.project}-${local.normalized_bucket_name}-inventory"
  }
  
  # バケット名の生成（重複回避）
  bucket_name = "${local.resource_names.bucket}-${random_string.bucket_suffix.result}"
}

# -----------------------------------------------------------------------------
# Random String for Bucket Name Uniqueness
# -----------------------------------------------------------------------------

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# -----------------------------------------------------------------------------
# S3 Bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = merge(
    local.common_tags,
    {
      Name = local.resource_names.bucket
    }
  )
}

# -----------------------------------------------------------------------------
# Bucket Versioning
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
    
    # 削除マーカーの管理
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# -----------------------------------------------------------------------------
# Server-Side Encryption
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_algorithm
      kms_master_key_id = var.encryption_algorithm == "aws:kms" ? var.kms_key_id : null
    }
    
    bucket_key_enabled = var.enable_bucket_key
  }
}

# -----------------------------------------------------------------------------
# Public Access Block
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# -----------------------------------------------------------------------------
# Bucket Ownership Controls
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = var.object_ownership
  }
}

# -----------------------------------------------------------------------------
# Bucket ACL
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_acl" "main" {
  count = var.bucket_acl != null ? 1 : 0
  
  depends_on = [
    aws_s3_bucket_ownership_controls.main,
    aws_s3_bucket_public_access_block.main
  ]

  bucket = aws_s3_bucket.main.id
  acl    = var.bucket_acl
}

# -----------------------------------------------------------------------------
# Lifecycle Configuration
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.enable_lifecycle_management ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    id     = "general-lifecycle"
    status = "Enabled"

    # フィルター設定（必須）
    filter {
      prefix = ""
    }

    # 非現行バージョンの管理
    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = var.noncurrent_version_storage_class
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # 削除マーカーの管理
    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_days
    }
  }

  # 古いオブジェクトの削除ルール
  dynamic "rule" {
    for_each = var.enable_object_expiration ? [1] : []
    content {
      id     = "object-expiration"
      status = "Enabled"

      # フィルター設定（必須）
      filter {
        prefix = ""
      }

      expiration {
        days = var.object_expiration_days
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Access Logging
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = "${local.resource_names.access_logs}-${random_string.bucket_suffix.result}"

  tags = merge(
    local.common_tags,
    {
      Name = local.resource_names.access_logs
      Purpose = "access-logs"
    }
  )
}

resource "aws_s3_bucket_versioning" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "main" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "logs/"
}

# -----------------------------------------------------------------------------
# Inventory Configuration
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "inventory" {
  count = var.enable_inventory ? 1 : 0

  bucket = "${local.resource_names.inventory}-${random_string.bucket_suffix.result}"

  tags = merge(
    local.common_tags,
    {
      Name = local.resource_names.inventory
      Purpose = "inventory"
    }
  )
}

resource "aws_s3_bucket_inventory" "main" {
  count = var.enable_inventory ? 1 : 0

  bucket = aws_s3_bucket.main.id
  name   = "inventory"

  included_object_versions = "All"

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.inventory[0].arn
      prefix     = "inventory/"
    }
  }
}

# -----------------------------------------------------------------------------
# CloudFront OAC Bucket Policy
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "main" {
  count = var.cloudfront_distribution_arn != "" ? 1 : 0

  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.main.arn}/*"
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

# -----------------------------------------------------------------------------
# Intelligent Tiering
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_intelligent_tiering_configuration" "main" {
  count = var.enable_intelligent_tiering ? 1 : 0

  bucket = aws_s3_bucket.main.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = var.deep_archive_access_days
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = var.archive_access_days
  }
}


