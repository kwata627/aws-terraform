# =============================================================================
# Network Module Variables
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

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

variable "public_subnets" {
  description = "パブリックサブネットの設定"
  type = list(object({
    cidr = string
    az   = string
    name = optional(string)
  }))
  validation {
    condition = alltrue([
      for subnet in var.public_subnets : can(cidrhost(subnet.cidr, 0))
    ])
    error_message = "すべてのパブリックサブネットに有効なCIDRブロックを指定してください。"
  }
}

variable "private_subnets" {
  description = "プライベートサブネットの設定"
  type = list(object({
    cidr = string
    az   = string
    name = optional(string)
  }))
  validation {
    condition = alltrue([
      for subnet in var.private_subnets : can(cidrhost(subnet.cidr, 0))
    ])
    error_message = "すべてのプライベートサブネットに有効なCIDRブロックを指定してください。"
  }
}

variable "nat_instance_network_interface_id" {
  description = "NATインスタンスのネットワークインターフェースID"
  type        = string
  default     = ""
}

variable "enable_nat_route" {
  description = "NATルートの有効化"
  type        = bool
  default     = true
}

variable "enable_network_acls" {
  description = "Network ACLの有効化"
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "VPCエンドポイントの有効化"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
}

variable "enable_flow_logs" {
  description = "VPC Flow Logsの有効化"
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Flow Logsの保持期間（日数）"
  type        = number
  default     = 30
  validation {
    condition     = var.flow_log_retention_days >= 1 && var.flow_log_retention_days <= 2555
    error_message = "Flow Logsの保持期間は1日から2555日の間である必要があります。"
  }
}
