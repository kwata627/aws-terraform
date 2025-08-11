# =============================================================================
# RDS Module Variables
# =============================================================================

variable "project" {
  description = "プロジェクト名"
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

variable "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  type        = list(string)
  validation {
    condition = length(var.private_subnet_ids) >= 2
    error_message = "RDSには最低2つのプライベートサブネットが必要です。"
  }
}

variable "rds_security_group_id" {
  description = "RDS用セキュリティグループのID"
  type        = string
  validation {
    condition     = can(regex("^sg-[a-z0-9]+$", var.rds_security_group_id))
    error_message = "有効なセキュリティグループIDを指定してください。"
  }
}

variable "db_instance_class" {
  description = "RDSインスタンスタイプ"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "有効なRDSインスタンスタイプを指定してください。"
  }
}

variable "allocated_storage" {
  description = "割り当てストレージサイズ（GB）"
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "ストレージサイズは20GBから65536GBの間である必要があります。"
  }
}

variable "max_allocated_storage" {
  description = "自動拡張の最大ストレージサイズ（GB）"
  type        = number
  default     = 100
  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage && var.max_allocated_storage <= 65536
    error_message = "最大ストレージサイズは割り当てストレージ以上で65536GB以下である必要があります。"
  }
}

variable "storage_type" {
  description = "ストレージタイプ"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["gp2", "gp3", "io1"], var.storage_type)
    error_message = "ストレージタイプは gp2, gp3, io1 のいずれかである必要があります。"
  }
}

variable "db_name" {
  description = "データベース名"
  type        = string
  default     = "wordpress"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.db_name))
    error_message = "データベース名は英数字とアンダースコアのみ使用可能です。"
  }
}

variable "db_username" {
  description = "データベースマスターユーザー名"
  type        = string
  default     = "admin"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.db_username))
    error_message = "ユーザー名は英数字とアンダースコアのみ使用可能です。"
  }
}

variable "db_password" {
  description = "データベースマスターパスワード"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "パスワードは8文字以上である必要があります。"
  }
}

variable "snapshot_date" {
  description = "スナップショット識別子用の日付 (例: 20240727)"
  type        = string
  default     = ""
  validation {
    condition     = var.snapshot_date == "" || can(regex("^[0-9]{8}$", var.snapshot_date))
    error_message = "スナップショット日付は空または8桁の数字である必要があります（例: 20240727）。"
  }
}

variable "enable_validation_rds" {
  description = "検証用RDSインスタンスの作成有無"
  type        = bool
  default     = false
}

variable "validation_rds_snapshot_identifier" {
  description = "検証用RDSのスナップショット識別子（空の場合は新規作成）"
  type        = string
  default     = ""
}

variable "rds_identifier" {
  description = "RDSインスタンスの識別子"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.rds_identifier))
    error_message = "RDS識別子は英数字とハイフンのみ使用可能です。"
  }
}

# セキュリティ設定
variable "deletion_protection" {
  description = "削除保護の有効化"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "ストレージ暗号化の有効化"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMSキーID（暗号化用）"
  type        = string
  default     = ""
}

variable "publicly_accessible" {
  description = "パブリックアクセスの有効化"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "マルチAZ配置の有効化"
  type        = bool
  default     = false
}

# バックアップ設定
variable "backup_retention_period" {
  description = "バックアップ保持期間（日）"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "バックアップ保持期間は0日から35日の間である必要があります。"
  }
}

variable "backup_window" {
  description = "バックアップ時間帯"
  type        = string
  default     = "03:00-04:00"
  validation {
    condition     = can(regex("^([0-1]?[0-9]|2[0-3]):[0-5][0-9]-([0-1]?[0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "バックアップ時間帯は正しい形式で指定してください（例: 03:00-04:00）。"
  }
}

variable "maintenance_window" {
  description = "メンテナンス時間帯"
  type        = string
  default     = "sun:04:00-sun:05:00"
  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([0-1]?[0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([0-1]?[0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "メンテナンス時間帯は正しい形式で指定してください（例: sun:04:00-sun:05:00）。"
  }
}

# 監視・ログ設定
variable "enable_cloudwatch_logs" {
  description = "CloudWatchログの有効化"
  type        = bool
  default     = false
}

variable "enable_performance_insights" {
  description = "Performance Insightsの有効化"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Performance Insights保持期間（日）"
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights保持期間は7日または731日である必要があります。"
  }
}

variable "enable_enhanced_monitoring" {
  description = "詳細モニタリングの有効化"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "モニタリング間隔（秒）"
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "モニタリング間隔は0, 1, 5, 10, 15, 30, 60秒のいずれかである必要があります。"
  }
}

# パラメータグループ設定
variable "parameter_group_family" {
  description = "パラメータグループファミリー"
  type        = string
  default     = "mysql8.0"
  validation {
    condition     = contains(["mysql8.0", "mysql5.7"], var.parameter_group_family)
    error_message = "パラメータグループファミリーは mysql8.0 または mysql5.7 である必要があります。"
  }
}

variable "db_parameters" {
  description = "データベースパラメータ"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "character_set_client"
      value = "utf8mb4"
    }
  ]
}

# タグ設定
variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
}