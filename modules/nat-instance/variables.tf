# =============================================================================
# NAT Instance Module Variables
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

variable "subnet_id" {
  description = "NATインスタンスを配置するパブリックサブネットID"
  type        = string
  
  validation {
    condition     = can(regex("^subnet-[a-z0-9]+$", var.subnet_id))
    error_message = "有効なサブネットIDを入力してください（例: subnet-xxxxxxxx）。"
  }
}

variable "security_group_id" {
  description = "NATインスタンス用のセキュリティグループID"
  type        = string
  
  validation {
    condition     = can(regex("^sg-[a-z0-9]+$", var.security_group_id))
    error_message = "有効なセキュリティグループIDを入力してください（例: sg-xxxxxxxx）。"
  }
}

variable "ami_id" {
  description = "NATインスタンス用AMI ID（Amazon Linux 2023）"
  type        = string
  
  validation {
    condition     = can(regex("^ami-[a-z0-9]+$", var.ami_id))
    error_message = "有効なAMI IDを入力してください（例: ami-xxxxxxxx）。"
  }
}

variable "instance_type" {
  description = "NATインスタンスのインスタンスタイプ（例: t3.nano）"
  type        = string
  default     = "t3.nano"
  
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "有効なインスタンスタイプを入力してください（例: t3.nano）。"
  }
}

variable "key_name" {
  description = "SSHキーペア名"
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

variable "ssh_private_key" {
  description = "SSH秘密鍵の内容（検証用インスタンス接続用）"
  type        = string
  sensitive   = true
  
  validation {
    condition     = can(regex("^-----BEGIN RSA PRIVATE KEY-----", var.ssh_private_key))
    error_message = "有効なSSH秘密鍵を入力してください。"
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

variable "vpc_cidr" {
  description = "VPCのCIDRブロック（NAT設定用）"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "有効なCIDRブロックを入力してください（例: 10.0.0.0/16）。"
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
  default     = "modules/nat-instance/userdata.tpl"
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
# Advanced Configuration Variables
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

variable "enable_network_interface" {
  description = "ネットワークインターフェースの有効化（高度なルーティング用）"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Computed Variables
# -----------------------------------------------------------------------------

locals {
  # NATインスタンス名の自動生成
  nat_instance_name = "${var.project}-nat-instance"
  
  # 高可用性設定
  high_availability_enabled = var.environment == "production"
} 