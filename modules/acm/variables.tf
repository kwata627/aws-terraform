# =============================================================================
# ACM Module Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project))
    error_message = "プロジェクト名は英数字とハイフンのみ使用可能です。"
  }
}

variable "domain_name" {
  description = "SSL証明書を発行するドメイン名（例: example.com）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])*$", var.domain_name))
    error_message = "有効なドメイン名を入力してください（例: example.com）。"
  }
}

variable "route53_zone_id" {
  description = "Route53ホストゾーンのID（DNS検証用レコードの作成に必要）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.route53_zone_id == "" || can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "有効なRoute53ゾーンIDを入力してください（例: Z1234567890ABC）。"
  }
}

# -----------------------------------------------------------------------------
# Optional Variables
# -----------------------------------------------------------------------------

variable "environment" {
  description = "環境名（dev, staging, production等）"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["dev", "staging", "production", "test"], var.environment)
    error_message = "環境名は dev, staging, production, test のいずれかである必要があります。"
  }
}

variable "subject_alternative_names" {
  description = "サブジェクト代替名（SAN）のリスト。ワイルドカード証明書を含む"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for san in var.subject_alternative_names : 
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])*$", san))
    ])
    error_message = "すべてのSANが有効なドメイン名である必要があります。"
  }
}

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for key, value in var.tags : 
      can(regex("^[a-zA-Z0-9_.:/=+-@]+$", key)) && 
      can(regex("^[a-zA-Z0-9_.:/=+-@]*$", value))
    ])
    error_message = "タグのキーと値は有効な文字のみ使用可能です。"
  }
}

# -----------------------------------------------------------------------------
# Advanced Configuration Variables
# -----------------------------------------------------------------------------

variable "validation_method" {
  description = "証明書の検証方式（DNSまたはEMAIL）"
  type        = string
  default     = "DNS"
  
  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "検証方式は DNS または EMAIL である必要があります。"
  }
}

variable "enable_wildcard" {
  description = "ワイルドカード証明書を有効にするかどうか"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Monitoring and Alerting Variables
# -----------------------------------------------------------------------------

variable "enable_expiry_monitoring" {
  description = "証明書の有効期限監視を有効にするかどうか"
  type        = bool
  default     = true
}

variable "enable_validation_monitoring" {
  description = "証明書の検証失敗監視を有効にするかどうか"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "アラーム発生時のアクション（SNSトピックARN等）"
  type        = list(string)
  default     = []
}

variable "expiry_threshold_days" {
  description = "有効期限アラートの閾値（日数）"
  type        = number
  default     = 30
  
  validation {
    condition     = var.expiry_threshold_days >= 1 && var.expiry_threshold_days <= 365
    error_message = "有効期限閾値は1日から365日の間である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Computed Variables
# -----------------------------------------------------------------------------

locals {
  # ワイルドカード証明書の自動追加
  wildcard_domain = var.enable_wildcard ? ["*.${var.domain_name}"] : []
  
  # 最終的なSANリスト（ワイルドカード + 手動指定）
  final_san_list = concat(var.subject_alternative_names, local.wildcard_domain)
}