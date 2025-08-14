# =============================================================================
# Main Terraform Variables (Refactored)
# =============================================================================
# 
# このファイルはメインTerraform設定の変数定義を含みます。
# セキュアなインフラ設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWSのリージョン"
  type        = string
  default     = "ap-northeast-1"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "有効なAWSリージョンを指定してください。"
  }
}

variable "aws_profile" {
  description = "AWS CLIのプロファイル名"
  type        = string
  default     = "default"
  
  validation {
    condition     = length(var.aws_profile) > 0 && length(var.aws_profile) <= 64
    error_message = "プロファイル名は1-64文字である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  default     = "wp-shamo"
  
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
# SSH Configuration
# -----------------------------------------------------------------------------

variable "ssh_key_name_suffix" {
  description = "SSHキーペア名のサフィックス"
  type        = string
  default     = "ssh-key"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.ssh_key_name_suffix)) && length(var.ssh_key_name_suffix) >= 1 && length(var.ssh_key_name_suffix) <= 20
    error_message = "SSHキー名サフィックスは1-20文字の小文字、数字、ハイフンのみ使用可能です。"
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

variable "public_subnet_cidr" {
  description = "パブリックサブネットのCIDR"
  type        = string
  default     = "10.0.1.0/24"
  
  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

variable "private_subnet_cidr" {
  description = "プライベートサブネットのCIDR"
  type        = string
  default     = "10.0.2.0/24"
  
  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

variable "az1" {
  description = "利用するアベイラビリティゾーン"
  type        = string
  default     = "ap-northeast-1a"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.az1))
    error_message = "有効なアベイラビリティゾーンを指定してください。"
  }
}

variable "enable_ssl_setup" {
  description = "SSL設定の自動実行を有効にするかどうか"
  type        = bool
  default     = false
  
  validation {
    condition     = contains([true, false], var.enable_ssl_setup)
    error_message = "enable_ssl_setupは true または false である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ（空の場合は自動生成: project名-ec2）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.ec2_name == "" || (length(var.ec2_name) >= 3 && length(var.ec2_name) <= 50)
    error_message = "EC2名は空または3-50文字である必要があります。"
  }
}

variable "validation_ec2_name" {
  description = "検証用EC2インスタンスのNameタグ（空の場合は自動生成: project名-test-ec2）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.validation_ec2_name == "" || (length(var.validation_ec2_name) >= 3 && length(var.validation_ec2_name) <= 50)
    error_message = "検証用EC2名は空または3-50文字である必要があります。"
  }
}

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023）"
  type        = string
  default     = "ami-095af7cb7ddb447ef"
  
  validation {
    condition     = can(regex("^ami-[a-z0-9]+$", var.ami_id))
    error_message = "有効なAMI IDを指定してください。"
  }
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "有効なインスタンスタイプを指定してください。"
  }
}

variable "root_volume_size" {
  description = "ルートボリュームのサイズ（GB）"
  type        = number
  default     = 8
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "ルートボリュームサイズは8GBから16384GBの間である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------

variable "rds_identifier" {
  description = "RDSインスタンスの識別子（空の場合は自動生成: project名-rds）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.rds_identifier == "" || (can(regex("^[a-z0-9-]+$", var.rds_identifier)) && length(var.rds_identifier) <= 63)
    error_message = "RDS識別子は空または3-63文字の小文字、数字、ハイフンのみ使用可能です。"
  }
}

variable "db_password" {
  description = "RDSマスターパスワード（必須）"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "データベースパスワードは8-128文字である必要があります。"
  }
}

variable "snapshot_date" {
  description = "スナップショット識別子用の日付 (例: 20250731)"
  type        = string
  default     = ""
  
  validation {
    condition     = var.snapshot_date == "" || can(regex("^[0-9]{8}$", var.snapshot_date))
    error_message = "スナップショット日付は空または8桁の数字（YYYYMMDD）で指定してください。"
  }
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------

variable "s3_bucket_name" {
  description = "S3バケット名（空の場合は自動生成: project名-s3）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.s3_bucket_name == "" || (can(regex("^[a-z0-9-]+$", var.s3_bucket_name)) && length(var.s3_bucket_name) <= 63)
    error_message = "S3バケット名は空または3-63文字の小文字、数字、ハイフンのみ使用可能です。"
  }
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "管理するドメイン名（例: example.com）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+$", var.domain_name))
    error_message = "有効なドメイン名を指定してください。"
  }
}

variable "register_domain" {
  description = "ドメイン登録を実行するかどうか（自動判定されるため、通常は変更不要）"
  type        = bool
  default     = false
}

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
      length(var.registrant_info.organization_name) >= 0,
      can(regex("^[^@]+@[^@]+\\.[^@]+$", var.registrant_info.email)),
      length(var.registrant_info.phone_number) > 0,
      length(var.registrant_info.address_line_1) > 0,
      length(var.registrant_info.city) > 0,
      length(var.registrant_info.state) > 0,
      length(var.registrant_info.country_code) == 2,
      length(var.registrant_info.zip_code) > 0
    ])
    error_message = "有効な登録者情報を指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Validation Environment Configuration
# -----------------------------------------------------------------------------

variable "enable_validation_ec2" {
  description = "検証用EC2インスタンスの作成有無"
  type        = bool
  default     = true
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
  
  validation {
    condition     = var.validation_rds_snapshot_identifier == "" || can(regex("^[a-zA-Z0-9-]+$", var.validation_rds_snapshot_identifier))
    error_message = "有効なスナップショット識別子を指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "ssh_allowed_cidr" {
  description = "SSH接続を許可するCIDRブロック（例: 203.0.113.0/24）"
  type        = string
  default     = "0.0.0.0/0"  # 注意：本番環境では特定IPに制限
  
  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Additional Tags
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

# -----------------------------------------------------------------------------
# CloudFront Configuration
# -----------------------------------------------------------------------------

variable "enable_cloudfront" {
  description = "CloudFrontディストリビューションの有効化"
  type        = bool
  default     = false  # CloudFront機能を無効化
}

# -----------------------------------------------------------------------------
# DNS Management Configuration
# -----------------------------------------------------------------------------

variable "auto_update_nameservers" {
  description = "ドメインのネームサーバーを自動更新するかどうか"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SSL/TLS Configuration (Let's Encrypt)
# -----------------------------------------------------------------------------

variable "enable_lets_encrypt" {
  description = "Let's Encrypt証明書の自動取得を有効にするかどうか"
  type        = bool
  default     = true
  
  validation {
    condition     = contains([true, false], var.enable_lets_encrypt)
    error_message = "enable_lets_encryptは true または false である必要があります。"
  }
}

variable "lets_encrypt_email" {
  description = "Let's Encrypt証明書の通知用メールアドレス"
  type        = string
  default     = "admin@example.com"
  
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.lets_encrypt_email))
    error_message = "有効なメールアドレスを指定してください。"
  }
}

variable "lets_encrypt_staging" {
  description = "Let's Encryptステージング環境を使用するかどうか（テスト用）"
  type        = bool
  default     = false
  
  validation {
    condition     = contains([true, false], var.lets_encrypt_staging)
    error_message = "lets_encrypt_stagingは true または false である必要があります。"
  }
}


