# =============================================================================
# CloudFront Module Variables (Refactored)
# =============================================================================
# 
# このファイルはCloudFrontモジュールの変数定義を含みます。
# セキュアなCDN設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------------------------

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project)) && length(var.project) >= 3 && length(var.project) <= 20
    error_message = "プロジェクト名は3-20文字の小文字、数字、ハイフンのみ使用可能です。"
  }
}

variable "environment" {
  description = "環境名（production, staging, development等）"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production", "staging", "development", "test"], var.environment)
    error_message = "環境名は production, staging, development, test のいずれかである必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Distribution Configuration
# -----------------------------------------------------------------------------

variable "enable_distribution" {
  description = "CloudFrontディストリビューションの有効化"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "IPv6の有効化"
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "デフォルトルートオブジェクト"
  type        = string
  default     = "index.html"
}

variable "origin_domain_name" {
  description = "CloudFrontのオリジンドメイン名（S3バケットのドメイン名）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+$", var.origin_domain_name))
    error_message = "有効なドメイン名を指定してください。"
  }
}

variable "origin_path" {
  description = "オリジンパス"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM証明書のARN（HTTPS用）"
  type        = string
  
  validation {
    condition     = can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-zA-Z0-9-]+$", var.acm_certificate_arn))
    error_message = "有効なACM証明書ARNを指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Cache Behavior Configuration
# -----------------------------------------------------------------------------

variable "allowed_methods" {
  description = "許可されるHTTPメソッド"
  type        = list(string)
  default     = ["GET", "HEAD"]
  
  validation {
    condition = alltrue([
      for method in var.allowed_methods : 
      contains(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"], method)
    ])
    error_message = "許可されるメソッドは GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE です。"
  }
}

variable "cached_methods" {
  description = "キャッシュされるHTTPメソッド"
  type        = list(string)
  default     = ["GET", "HEAD"]
  
  validation {
    condition = alltrue([
      for method in var.cached_methods : 
      contains(["GET", "HEAD"], method)
    ])
    error_message = "キャッシュされるメソッドは GET, HEAD のみです。"
  }
}

variable "viewer_protocol_policy" {
  description = "ビューワープロトコルポリシー"
  type        = string
  default     = "redirect-to-https"
  
  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "ビューワープロトコルポリシーは allow-all, https-only, redirect-to-https のいずれかである必要があります。"
  }
}

variable "min_ttl" {
  description = "最小TTL（秒）"
  type        = number
  default     = 0
  
  validation {
    condition     = var.min_ttl >= 0
    error_message = "最小TTLは0以上である必要があります。"
  }
}

variable "default_ttl" {
  description = "デフォルトTTL（秒）"
  type        = number
  default     = 3600
  
  validation {
    condition     = var.default_ttl >= 0
    error_message = "デフォルトTTLは0以上である必要があります。"
  }
}

variable "max_ttl" {
  description = "最大TTL（秒）"
  type        = number
  default     = 86400
  
  validation {
    condition     = var.max_ttl >= 0
    error_message = "最大TTLは0以上である必要があります。"
  }
}

variable "enable_compression" {
  description = "圧縮の有効化"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "enable_security_headers" {
  description = "セキュリティヘッダーの有効化"
  type        = bool
  default     = true
}

variable "minimum_protocol_version" {
  description = "最小TLSプロトコルバージョン"
  type        = string
  default     = "TLSv1.2_2021"
  
  validation {
    condition     = contains(["TLSv1", "TLSv1.1", "TLSv1.2", "TLSv1.2_2019", "TLSv1.2_2021", "TLSv1.3"], var.minimum_protocol_version)
    error_message = "最小プロトコルバージョンは TLSv1, TLSv1.1, TLSv1.2, TLSv1.2_2019, TLSv1.2_2021, TLSv1.3 のいずれかである必要があります。"
  }
}

variable "enable_waf" {
  description = "WAFの有効化"
  type        = bool
  default     = false
}

variable "enable_shield" {
  description = "AWS Shieldの有効化"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Logging and Monitoring
# -----------------------------------------------------------------------------

variable "enable_access_logs" {
  description = "アクセスログの有効化"
  type        = bool
  default     = false
}

variable "access_log_retention_days" {
  description = "アクセスログの保持期間（日数）"
  type        = number
  default     = 90
  
  validation {
    condition     = var.access_log_retention_days >= 1 && var.access_log_retention_days <= 365
    error_message = "アクセスログ保持期間は1日から365日の間で指定してください。"
  }
}

variable "include_cookies_in_logs" {
  description = "ログにクッキーを含める"
  type        = bool
  default     = false
}

variable "enable_real_time_logs" {
  description = "リアルタイムログの有効化"
  type        = bool
  default     = false
}

variable "enable_real_time_metrics" {
  description = "リアルタイムメトリクスの有効化"
  type        = bool
  default     = false
}

variable "monitoring_retention_days" {
  description = "監視ログの保持期間（日数）"
  type        = number
  default     = 30
  
  validation {
    condition     = var.monitoring_retention_days >= 1 && var.monitoring_retention_days <= 365
    error_message = "監視ログ保持期間は1日から365日の間で指定してください。"
  }
}

variable "enable_monitoring_alarms" {
  description = "監視アラームの有効化"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Edge Functions
# -----------------------------------------------------------------------------

variable "enable_edge_functions" {
  description = "エッジ関数の有効化"
  type        = bool
  default     = false
}

variable "edge_functions" {
  description = "エッジ関数の設定"
  type = list(object({
    event_type   = string
    function_arn = string
  }))
  default = []
  
  validation {
    condition = alltrue([
      for func in var.edge_functions : 
      contains(["viewer-request", "viewer-response", "origin-request", "origin-response"], func.event_type)
    ])
    error_message = "イベントタイプは viewer-request, viewer-response, origin-request, origin-response のいずれかである必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Custom Error Responses
# -----------------------------------------------------------------------------

variable "custom_error_responses" {
  description = "カスタムエラーレスポンスの設定"
  type = list(object({
    error_code            = number
    response_code         = string
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = []
  
  validation {
    condition = alltrue([
      for response in var.custom_error_responses : 
      response.error_code >= 400 && response.error_code <= 599
    ])
    error_message = "エラーコードは400から599の間である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Geographic Restrictions
# -----------------------------------------------------------------------------

variable "geo_restriction_type" {
  description = "地理的制限のタイプ"
  type        = string
  default     = "none"
  
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "地理的制限タイプは none, whitelist, blacklist のいずれかである必要があります。"
  }
}

variable "geo_restriction_locations" {
  description = "地理的制限の場所"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Price Class
# -----------------------------------------------------------------------------

variable "price_class" {
  description = "価格クラス"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "価格クラスは PriceClass_100, PriceClass_200, PriceClass_All のいずれかである必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for key, value in var.tags : 
      length(key) > 0 && length(key) <= 128 &&
      length(value) <= 256
    ])
    error_message = "タグのキーは1-128文字、値は256文字以内である必要があります。"
  }
}