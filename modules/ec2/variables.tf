# =============================================================================
# EC2 Module Variables
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

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023推奨）"
  type        = string
  default     = "ami-095af7cb7ddb447ef"  # Amazon Linux 2023 (ap-northeast-1)
  
  validation {
    condition     = can(regex("^ami-[a-z0-9]+$", var.ami_id))
    error_message = "有効なAMI IDを入力してください（例: ami-xxxxxxxx）。"
  }
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "有効なインスタンスタイプを入力してください（例: t2.micro）。"
  }
}

variable "subnet_id" {
  description = "EC2インスタンスを配置するサブネットID"
  type        = string
  
  validation {
    condition     = can(regex("^subnet-[a-z0-9]+$", var.subnet_id))
    error_message = "有効なサブネットIDを入力してください（例: subnet-xxxxxxxx）。"
  }
}

variable "security_group_id" {
  description = "EC2インスタンス用のセキュリティグループID"
  type        = string
  
  validation {
    condition     = can(regex("^sg-[a-z0-9]+$", var.security_group_id))
    error_message = "有効なセキュリティグループIDを入力してください（例: sg-xxxxxxxx）。"
  }
}

variable "key_name" {
  description = "統一されたSSHキーペア名"
  type        = string
  
  validation {
    condition     = length(var.key_name) > 0
    error_message = "キーペア名は必須です。"
  }
}

variable "ssh_public_key" {
  description = "SSH公開鍵の内容"
  type        = string
  
  validation {
    condition     = can(regex("^ssh-rsa ", var.ssh_public_key))
    error_message = "有効なSSH公開鍵を入力してください。"
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

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
  default     = ""
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

variable "root_volume_type" {
  description = "ルートボリュームのタイプ"
  type        = string
  default     = "gp2"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "standard"], var.root_volume_type)
    error_message = "ボリュームタイプは gp2, gp3, io1, io2, standard のいずれかである必要があります。"
  }
}

variable "root_volume_encrypted" {
  description = "ルートボリュームの暗号化"
  type        = bool
  default     = true
}

variable "delete_on_termination" {
  description = "インスタンス終了時のボリューム削除"
  type        = bool
  default     = true
}

variable "associate_public_ip" {
  description = "パブリックIPの割り当て"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "詳細モニタリングの有効化"
  type        = bool
  default     = false
}

variable "shutdown_behavior" {
  description = "シャットダウン時の動作"
  type        = string
  default     = "stop"
  
  validation {
    condition     = contains(["stop", "terminate"], var.shutdown_behavior)
    error_message = "シャットダウン動作は stop または terminate である必要があります。"
  }
}

variable "user_data_template_path" {
  description = "UserDataテンプレートファイルのパス"
  type        = string
  default     = "modules/ec2/userdata_minimal.tpl"
}

variable "additional_user_data_scripts" {
  description = "追加のUserDataスクリプト"
  type        = string
  default     = ""
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
# Validation Environment Variables
# -----------------------------------------------------------------------------

variable "enable_validation_ec2" {
  description = "検証用EC2インスタンスの作成有無"
  type        = bool
  default     = false
}

variable "validation_instance_type" {
  description = "検証用EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.validation_instance_type))
    error_message = "有効なインスタンスタイプを入力してください（例: t2.micro）。"
  }
}

variable "private_subnet_id" {
  description = "検証用EC2インスタンスを配置するプライベートサブネットID"
  type        = string
  default     = ""
  
  validation {
    condition     = var.private_subnet_id == "" || can(regex("^subnet-[a-z0-9]+$", var.private_subnet_id))
    error_message = "有効なサブネットIDを入力してください（例: subnet-xxxxxxxx）。"
  }
}

variable "validation_security_group_id" {
  description = "検証用EC2インスタンス用のセキュリティグループID"
  type        = string
  default     = ""
  
  validation {
    condition     = var.validation_security_group_id == "" || can(regex("^sg-[a-z0-9]+$", var.validation_security_group_id))
    error_message = "有効なセキュリティグループIDを入力してください（例: sg-xxxxxxxx）。"
  }
}

variable "validation_ec2_name" {
  description = "検証用EC2インスタンスのNameタグ"
  type        = string
  default     = ""
}

variable "validation_root_volume_size" {
  description = "検証用EC2インスタンスのルートボリュームサイズ（GB）"
  type        = number
  default     = 8
  
  validation {
    condition     = var.validation_root_volume_size >= 8 && var.validation_root_volume_size <= 16384
    error_message = "ルートボリュームサイズは8GBから16384GBの間である必要があります。"
  }
}

variable "validation_user_data_template_path" {
  description = "検証用UserDataテンプレートファイルのパス"
  type        = string
  default     = "modules/ec2/userdata_minimal.tpl"
}

# -----------------------------------------------------------------------------
# Monitoring Variables
# -----------------------------------------------------------------------------

variable "enable_cloudwatch_alarms" {
  description = "CloudWatchアラームの有効化"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "CloudWatchアラームのアクション（SNSトピックARN等）"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Computed Variables
# -----------------------------------------------------------------------------

locals {
  # インスタンス名の自動生成
  production_instance_name = var.ec2_name != "" ? var.ec2_name : "${var.project}-wordpress-ec2"
  validation_instance_name = var.validation_ec2_name != "" ? var.validation_ec2_name : "${var.project}-validation-ec2"
  
  # 検証環境の有効性チェック（リソース属性に依存しない）
  validation_enabled = var.enable_validation_ec2
}