# =============================================================================
# CloudFront Module Outputs (Refactored)
# =============================================================================
# 
# このファイルはCloudFrontモジュールの出力定義を含みます。
# セキュアなCDN設定とセキュリティ機能に対応しています。
# =============================================================================

# -----------------------------------------------------------------------------
# Distribution Information
# -----------------------------------------------------------------------------

output "distribution_id" {
  description = "CloudFrontディストリビューションのID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "CloudFrontディストリビューションのARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "domain_name" {
  description = "CloudFrontディストリビューションのドメイン名"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_status" {
  description = "CloudFrontディストリビューションのステータス"
  value       = aws_cloudfront_distribution.main.status
}

output "distribution_enabled" {
  description = "CloudFrontディストリビューションの有効化状態"
  value       = aws_cloudfront_distribution.main.enabled
}

# -----------------------------------------------------------------------------
# Origin Access Control
# -----------------------------------------------------------------------------

output "origin_access_control_id" {
  description = "オリジンアクセス制御のID"
  value       = aws_cloudfront_origin_access_control.main.id
}

output "origin_access_control_arn" {
  description = "オリジンアクセス制御のARN"
  value       = aws_cloudfront_origin_access_control.main.arn
}

# -----------------------------------------------------------------------------
# Security Headers
# -----------------------------------------------------------------------------

output "security_headers_policy_id" {
  description = "セキュリティヘッダーポリシーのID"
  value       = var.enable_security_headers ? aws_cloudfront_response_headers_policy.security[0].id : null
}

output "security_headers_policy_arn" {
  description = "セキュリティヘッダーポリシーのARN"
  value       = var.enable_security_headers ? aws_cloudfront_response_headers_policy.security[0].arn : null
}

# -----------------------------------------------------------------------------
# Real-time Logs
# -----------------------------------------------------------------------------

output "realtime_log_config_arn" {
  description = "リアルタイムログ設定のARN"
  value       = var.enable_real_time_logs ? aws_cloudfront_realtime_log_config.main[0].arn : null
}

output "kinesis_stream_arn" {
  description = "リアルタイムログ用KinesisストリームのARN"
  value       = var.enable_real_time_logs ? aws_kinesis_stream.realtime_logs[0].arn : null
}

output "realtime_logs_role_arn" {
  description = "リアルタイムログ用IAMロールのARN"
  value       = var.enable_real_time_logs ? aws_iam_role.realtime_logs[0].arn : null
}

# -----------------------------------------------------------------------------
# Access Logs
# -----------------------------------------------------------------------------

output "access_logs_bucket_name" {
  description = "アクセスログ用S3バケット名"
  value       = var.enable_access_logs ? aws_s3_bucket.access_logs[0].bucket : null
}

output "access_logs_bucket_arn" {
  description = "アクセスログ用S3バケットのARN"
  value       = var.enable_access_logs ? aws_s3_bucket.access_logs[0].arn : null
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

output "monitoring_log_group_name" {
  description = "監視ロググループ名"
  value       = var.enable_real_time_metrics ? aws_cloudwatch_log_group.cloudfront_monitoring[0].name : null
}

output "monitoring_log_group_arn" {
  description = "監視ロググループのARN"
  value       = var.enable_real_time_metrics ? aws_cloudwatch_log_group.cloudfront_monitoring[0].arn : null
}

# -----------------------------------------------------------------------------
# Security Features Status
# -----------------------------------------------------------------------------

output "security_features_enabled" {
  description = "有効化されているセキュリティ機能"
  value = {
    security_headers = var.enable_security_headers
    waf = var.enable_waf
    shield = var.enable_shield
    real_time_logs = var.enable_real_time_logs
  }
}

output "monitoring_features_enabled" {
  description = "有効化されている監視機能"
  value = {
    access_logs = var.enable_access_logs
    real_time_metrics = var.enable_real_time_metrics
    monitoring_alarms = var.enable_monitoring_alarms
  }
}

# -----------------------------------------------------------------------------
# Configuration Summary
# -----------------------------------------------------------------------------

output "distribution_config" {
  description = "ディストリビューション設定"
  value = {
    enabled = local.distribution_config.enabled
    ipv6_enabled = local.distribution_config.ipv6_enabled
    default_root_object = local.distribution_config.default_root_object
    price_class = var.price_class
    geo_restriction_type = var.geo_restriction_type
  }
}

output "cache_behavior_config" {
  description = "キャッシュビヘイビア設定"
  value = {
    allowed_methods = local.cache_behavior_config.allowed_methods
    cached_methods = local.cache_behavior_config.cached_methods
    viewer_protocol_policy = local.cache_behavior_config.viewer_protocol_policy
    min_ttl = local.cache_behavior_config.min_ttl
    default_ttl = local.cache_behavior_config.default_ttl
    max_ttl = local.cache_behavior_config.max_ttl
    compress = local.cache_behavior_config.compress
  }
}

# -----------------------------------------------------------------------------
# Module Summary
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "CloudFrontモジュールの設定サマリー"
  value = {
    project = var.project
    environment = var.environment
    distribution_id = aws_cloudfront_distribution.main.id
    domain_name = aws_cloudfront_distribution.main.domain_name
    enabled = aws_cloudfront_distribution.main.enabled
    security_headers_enabled = var.enable_security_headers
    access_logs_enabled = var.enable_access_logs
    real_time_logs_enabled = var.enable_real_time_logs
    monitoring_alarms_enabled = var.enable_monitoring_alarms
  }
}
