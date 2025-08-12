# =============================================================================
# Route53 Module Variables
# =============================================================================

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "プロジェクト名は小文字、数字、ハイフンのみ使用可能です。"
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

variable "domain_name" {
  description = "管理するドメイン名（例: example.com）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "有効なドメイン名を指定してください（例: example.com）。"
  }
}

variable "wordpress_ip" {
  description = "WordPress EC2インスタンスのIPアドレス"
  type        = string
  default     = ""
  
  validation {
    condition     = var.wordpress_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.wordpress_ip))
    error_message = "有効なIPv4アドレスを指定してください。"
  }
}

variable "cloudfront_domain_name" {
  description = "CloudFrontディストリビューションのドメイン名"
  type        = string
  default     = ""
  
  validation {
    condition     = var.cloudfront_domain_name == "" || can(regex("^[a-zA-Z0-9.-]+\\.cloudfront\\.net$", var.cloudfront_domain_name))
    error_message = "有効なCloudFrontドメイン名を入力してください（例: d1234567890abc.cloudfront.net）。"
  }
}



variable "register_domain" {
  description = "ドメイン登録を実行するかどうか（自動判定されるため、通常は変更不要）"
  type        = bool
  default     = false
}

# ドメイン分析結果
variable "should_use_existing_zone" {
  description = "既存のRoute53ホストゾーンを使用するかどうか"
  type        = bool
  default     = false
}

variable "domain_exists_in_route53" {
  description = "Route53にホストゾーンが存在するかどうか"
  type        = bool
  default     = false
}

variable "domain_exists_in_dns" {
  description = "DNSにネームサーバーが存在するかどうか"
  type        = bool
  default     = false
}

variable "domain_registered" {
  description = "ドメインが登録済みかどうか"
  type        = bool
  default     = false
}

# ドメイン登録用の登録者情報
variable "registrant_info" {
  description = "ドメイン登録者の情報"
  type = object({
    first_name        = string
    last_name         = string
    organization_name = string
    email            = string
    phone_number     = string
    address_line_1   = string
    city             = string
    state            = string
    country_code     = string
    zip_code         = string
  })
  default = {
    first_name        = "Admin"
    last_name         = "User"
    organization_name = "My Organization"
    email            = "admin@example.com"
    phone_number     = "+81.1234567890"
    address_line_1   = "123 Main Street"
    city             = "Tokyo"
    state            = "Tokyo"
    country_code     = "JP"
    zip_code         = "100-0001"
  }
  
  validation {
    condition = alltrue([
      length(var.registrant_info.first_name) > 0,
      length(var.registrant_info.last_name) > 0,
      can(regex("^[^@]+@[^@]+\\.[^@]+$", var.registrant_info.email)),
      length(var.registrant_info.phone_number) > 0,
      can(regex("^\\+[0-9]+\\.[0-9-]+$", var.registrant_info.phone_number)),
      length(var.registrant_info.address_line_1) > 0,
      length(var.registrant_info.city) > 0,
      length(var.registrant_info.state) > 0,
      var.registrant_info.country_code == "JP",
      length(var.registrant_info.zip_code) > 0
    ])
    error_message = "登録者情報の形式が正しくありません。電話番号は +81.80-4178-3008 の形式で、国コードは JP である必要があります。組織名は空でも構いません。"
  }
}

# DNSレコード設定
variable "dns_records" {
  description = "追加のDNSレコード設定"
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
    alias   = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
    health_check_id = optional(string)
    set_identifier  = optional(string)
    failover       = optional(string)
    geolocation    = optional(string)
    latency        = optional(string)
    weighted       = optional(number)
  }))
  default = []
  
  validation {
    condition = alltrue([
      for record in var.dns_records : 
      length(record.name) > 0 &&
      contains(["A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "SPF", "SRV", "TXT"], record.type) &&
      record.ttl >= 0 &&
      length(record.records) > 0
    ])
    error_message = "DNSレコードの設定が正しくありません。"
  }
}

# ヘルスチェック設定
variable "enable_health_checks" {
  description = "ヘルスチェックの有効化"
  type        = bool
  default     = false
}

variable "health_checks" {
  description = "ヘルスチェック設定"
  type = list(object({
    name                = string
    fqdn               = string
    port               = optional(number, 80)
    type               = optional(string, "HTTP")
    resource_path      = optional(string, "/")
    failure_threshold  = optional(number, 3)
    request_interval   = optional(number, 30)
    tags               = optional(map(string), {})
  }))
  default = []
  
  validation {
    condition = alltrue([
      for check in var.health_checks : 
      length(check.name) > 0 &&
      can(regex("^[a-zA-Z0-9.-]+$", check.fqdn)) &&
      check.port >= 1 && check.port <= 65535 &&
      contains(["HTTP", "HTTPS", "HTTP_STR_MATCH", "HTTPS_STR_MATCH", "TCP", "CALCULATED", "CLOUDWATCH_METRIC"], check.type) &&
      check.failure_threshold >= 1 && check.failure_threshold <= 10 &&
      check.request_interval >= 10 && check.request_interval <= 30
    ])
    error_message = "ヘルスチェックの設定が正しくありません。"
  }
}

# DNSクエリログ設定
variable "enable_query_logging" {
  description = "DNSクエリログの有効化"
  type        = bool
  default     = false
}

variable "query_log_group_name" {
  description = "CloudWatch Log Group名（DNSクエリログ用）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.query_log_group_name == "" || can(regex("^[a-zA-Z0-9/_-]+$", var.query_log_group_name))
    error_message = "CloudWatch Log Group名は英数字、スラッシュ、アンダースコア、ハイフンのみ使用可能です。"
  }
}

variable "query_log_retention_days" {
  description = "DNSクエリログの保持期間（日数）"
  type        = number
  default     = 30
  
  validation {
    condition     = var.query_log_retention_days >= 1 && var.query_log_retention_days <= 2555
    error_message = "DNSクエリログの保持期間は1日から2555日の間である必要があります。"
  }
}

# DNSSEC設定
variable "enable_dnssec" {
  description = "DNSSECの有効化"
  type        = bool
  default     = false
}

variable "dnssec_signing_algorithm" {
  description = "DNSSEC署名アルゴリズム"
  type        = string
  default     = "RSASHA256"
  
  validation {
    condition     = contains(["RSASHA256", "RSASHA1", "RSASHA512", "ECDSAP256SHA256", "ECDSAP384SHA384"], var.dnssec_signing_algorithm)
    error_message = "DNSSEC署名アルゴリズムは RSASHA256, RSASHA1, RSASHA512, ECDSAP256SHA256, ECDSAP384SHA384 のいずれかである必要があります。"
  }
}

# プライベートホストゾーン設定
variable "is_private_zone" {
  description = "プライベートホストゾーンの有効化"
  type        = bool
  default     = false
}

variable "private_zone_vpc_ids" {
  description = "プライベートホストゾーンに関連付けるVPC ID一覧"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for vpc_id in var.private_zone_vpc_ids : 
      can(regex("^vpc-[a-z0-9]+$", vpc_id))
    ])
    error_message = "VPC IDは vpc- で始まる有効なIDである必要があります。"
  }
}

# タグ設定
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