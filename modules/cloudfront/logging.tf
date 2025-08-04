# =============================================================================
# CloudFront Module - Logging and Monitoring
# =============================================================================
# 
# このファイルはCloudFrontモジュールのログ機能と監視機能を含みます。
# アクセスログとリアルタイムログを提供します。
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Bucket for Access Logs (Optional)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = "${var.project}-cloudfront-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Purpose = "cloudfront-access-logs"
    }
  )
}

resource "aws_s3_bucket_versioning" "access_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = aws_s3_bucket.access_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "cloudfront-logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.access_log_retention_days
    }

    expiration {
      days = var.access_log_retention_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Monitoring (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudfront_monitoring" {
  count = var.enable_real_time_metrics ? 1 : 0
  
  name              = "/aws/cloudfront/${var.project}/monitoring"
  retention_in_days = var.monitoring_retention_days

  tags = merge(
    local.common_tags,
    {
      Purpose = "cloudfront-monitoring"
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Monitoring (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cloudfront_errors" {
  count = var.enable_monitoring_alarms ? 1 : 0
  
  alarm_name          = "${var.project}-cloudfront-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Requests"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "CloudFrontエラー率が閾値を超えた場合のアラーム"
  
  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
    Region         = "Global"
  }

  tags = merge(
    local.common_tags,
    {
      Purpose = "cloudfront-monitoring"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_latency" {
  count = var.enable_monitoring_alarms ? 1 : 0
  
  alarm_name          = "${var.project}-cloudfront-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TotalErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5.0
  alarm_description   = "CloudFrontレイテンシーが閾値を超えた場合のアラーム"
  
  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
    Region         = "Global"
  }

  tags = merge(
    local.common_tags,
    {
      Purpose = "cloudfront-monitoring"
    }
  )
} 