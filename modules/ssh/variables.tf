# =============================================================================
# SSH Module Variables (Refactored)
# =============================================================================
# 
# このファイルはSSHモジュールの変数定義を含みます。
# セキュアなSSHキーペア管理とベストプラクティスに沿った設計となっています。
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
# SSH Key Configuration
# -----------------------------------------------------------------------------

variable "key_name_suffix" {
  description = "SSHキーペア名のサフィックス"
  type        = string
  default     = "ssh-key"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.key_name_suffix)) && length(var.key_name_suffix) >= 1 && length(var.key_name_suffix) <= 20
    error_message = "キー名サフィックスは1-20文字の小文字、数字、ハイフンのみ使用可能です。"
  }
}

variable "key_algorithm" {
  description = "SSHキーのアルゴリズム"
  type        = string
  default     = "RSA"
  
  validation {
    condition     = contains(["RSA", "ECDSA"], var.key_algorithm)
    error_message = "アルゴリズムは RSA または ECDSA である必要があります。"
  }
}

variable "rsa_bits" {
  description = "RSAキーのビット数"
  type        = number
  default     = 4096
  
  validation {
    condition     = contains([2048, 3072, 4096], var.rsa_bits)
    error_message = "RSAビット数は 2048, 3072, 4096 のいずれかである必要があります。"
  }
}

variable "ecdsa_curve" {
  description = "ECDSAキーの曲線"
  type        = string
  default     = "P256"
  
  validation {
    condition     = contains(["P224", "P256", "P384", "P521"], var.ecdsa_curve)
    error_message = "ECDSA曲線は P224, P256, P384, P521 のいずれかである必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Security Features
# -----------------------------------------------------------------------------

variable "enable_key_rotation" {
  description = "SSHキーの自動ローテーション機能の有効化"
  type        = bool
  default     = false
}

variable "key_rotation_days" {
  description = "SSHキーのローテーション間隔（日数）"
  type        = number
  default     = 90
  
  validation {
    condition     = var.key_rotation_days >= 30 && var.key_rotation_days <= 365
    error_message = "ローテーション間隔は30日から365日の間で指定してください。"
  }
}

variable "enable_backup" {
  description = "SSHキーのバックアップ機能の有効化"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "SSHキーバックアップの保持期間（日数）"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "バックアップ保持期間は1日から365日の間で指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Audit and Monitoring
# -----------------------------------------------------------------------------

variable "enable_audit_logs" {
  description = "SSHキー監査ログ機能の有効化"
  type        = bool
  default     = false
}

variable "audit_retention_days" {
  description = "SSHキー監査ログの保持期間（日数）"
  type        = number
  default     = 90
  
  validation {
    condition     = var.audit_retention_days >= 1 && var.audit_retention_days <= 365
    error_message = "監査ログ保持期間は1日から365日の間で指定してください。"
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