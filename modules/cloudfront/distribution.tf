# =============================================================================
# CloudFront Module - Distribution
# =============================================================================
# 
# このファイルはCloudFrontモジュールのディストリビューション定義を含みます。
# セキュアなCDN設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# CloudFront Distribution
# -----------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "main" {
  enabled             = local.distribution_config.enabled
  is_ipv6_enabled    = local.distribution_config.ipv6_enabled
  default_root_object = local.distribution_config.default_root_object
  comment             = local.distribution_config.description

  # オリジンドメインの設定
  origin {
    domain_name = local.origin_config.domain_name
    origin_id   = local.origin_config.origin_id
    origin_path = local.origin_config.origin_path

    # S3オリジンアクセス制御
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # デフォルトキャッシュビヘイビアの設定
  default_cache_behavior {
    allowed_methods  = local.cache_behavior_config.allowed_methods
    cached_methods   = local.cache_behavior_config.cached_methods
    target_origin_id = local.cache_behavior_config.target_origin_id

    viewer_protocol_policy = local.cache_behavior_config.viewer_protocol_policy
    min_ttl                = local.cache_behavior_config.min_ttl
    default_ttl            = local.cache_behavior_config.default_ttl
    max_ttl                = local.cache_behavior_config.max_ttl
    compress               = local.cache_behavior_config.compress

    # セキュリティヘッダーの設定
    dynamic "response_headers_policy_id" {
      for_each = var.enable_security_headers ? [1] : []
      content {
        response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id
      }
    }

    # 関数の設定
    dynamic "function_association" {
      for_each = var.enable_edge_functions ? var.edge_functions : []
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  # カスタムエラーページの設定
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # 価格クラスの設定
  price_class = var.price_class

  # 制限設定
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # ビューワー証明書の設定
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = local.security_config.minimum_protocol_version
  }

  # アクセスログの設定
  dynamic "logging_config" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      include_cookies = var.include_cookies_in_logs
      bucket          = aws_s3_bucket.access_logs[0].bucket_domain_name
      prefix          = "cloudfront-logs/"
    }
  }

  # リアルタイムログの設定
  dynamic "realtime_log_config_arn" {
    for_each = var.enable_real_time_logs ? [1] : []
    content {
      realtime_log_config_arn = aws_cloudfront_realtime_log_config.main[0].arn
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.distribution_config.name
      Purpose = "cdn-distribution"
      SecurityLevel = "high"
    }
  )
}

# -----------------------------------------------------------------------------
# Origin Access Control
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project}-oac"
  description                       = "S3 origin access control for ${var.project}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -----------------------------------------------------------------------------
# Response Headers Policy (Security Headers)
# -----------------------------------------------------------------------------

resource "aws_cloudfront_response_headers_policy" "security" {
  count = var.enable_security_headers ? 1 : 0
  
  name    = "${var.project}-security-headers"
  comment = "Security headers policy for ${var.project}"

  security_headers_config {
    content_type_options {
      override = true
    }
    
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
    
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }
}

# -----------------------------------------------------------------------------
# Real-time Log Configuration (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudfront_realtime_log_config" "main" {
  count = var.enable_real_time_logs ? 1 : 0
  
  name   = "${var.project}-realtime-logs"
  fields = ["timestamp", "time-to-first-byte", "sc-status", "sc-bytes", "c-ip", "cs-method", "cs-host", "cs-uri-stem", "cs-bytes", "x-forwarded-for", "ssl-protocol", "ssl-cipher", "x-result-type", "x-forwarded-proto", "fle-status", "fle-encrypted-fields", "c-port", "time-taken", "x-forwarded-for-2", "sc-content-type", "sc-content-len", "sc-range-start", "sc-range-end"]

  endpoint {
    stream_type = "Kinesis"

    kinesis_stream_config {
      role_arn   = aws_iam_role.realtime_logs[0].arn
      stream_arn = aws_kinesis_stream.realtime_logs[0].arn
    }
  }
}

# -----------------------------------------------------------------------------
# Kinesis Stream for Real-time Logs (Optional)
# -----------------------------------------------------------------------------

resource "aws_kinesis_stream" "realtime_logs" {
  count = var.enable_real_time_logs ? 1 : 0
  
  name             = "${var.project}-realtime-logs"
  shard_count      = 1
  retention_period = 24

  tags = merge(
    local.common_tags,
    {
      Purpose = "realtime-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM Role for Real-time Logs (Optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "realtime_logs" {
  count = var.enable_real_time_logs ? 1 : 0
  
  name = "${var.project}-realtime-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Purpose = "realtime-logs"
    }
  )
}

resource "aws_iam_role_policy" "realtime_logs" {
  count = var.enable_real_time_logs ? 1 : 0
  
  name = "${var.project}-realtime-logs-policy"
  role = aws_iam_role.realtime_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.realtime_logs[0].arn
      }
    ]
  })
} 