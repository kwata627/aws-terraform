# =============================================================================
# CloudFront Module - Local Values
# =============================================================================
# 
# このファイルはCloudFrontモジュールのローカル値定義を含みます。
# CloudFrontディストリビューションの設定とタグ管理を効率的に行います。
# =============================================================================

locals {
  # 共通タグ
  common_tags = merge(
    {
      Name        = "${var.project}-cloudfront"
      Environment = var.environment
      Module      = "cloudfront"
      ManagedBy   = "terraform"
      Project     = var.project
      Security    = "high"
      CreatedAt   = timestamp()
      Version     = "2.0.0"
    },
    var.tags
  )
  
  # CloudFrontディストリビューション設定
  distribution_config = {
    name        = "${var.project}-cloudfront"
    description = "CloudFront distribution for ${var.project}"
    enabled     = var.enable_distribution
    ipv6_enabled = var.enable_ipv6
    default_root_object = var.default_root_object
  }
  
  # オリジン設定
  origin_config = {
    domain_name = var.origin_domain_name
    origin_id   = "S3-${var.project}-static-files"
    origin_path = var.origin_path
  }
  
  # キャッシュビヘイビア設定
  cache_behavior_config = {
    allowed_methods = var.allowed_methods
    cached_methods  = var.cached_methods
    target_origin_id = "S3-${var.project}-static-files"
    viewer_protocol_policy = var.viewer_protocol_policy
    min_ttl = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl = var.max_ttl
    compress = var.enable_compression
  }
  
  # セキュリティ設定
  security_config = {
    enable_waf = var.enable_waf
    enable_shield = var.enable_shield
    enable_real_time_logs = var.enable_real_time_logs
    minimum_protocol_version = var.minimum_protocol_version
  }
  
  # 監視設定
  monitoring_config = {
    enable_access_logs = var.enable_access_logs
    access_log_retention_days = var.access_log_retention_days
    enable_real_time_metrics = var.enable_real_time_metrics
  }
} 