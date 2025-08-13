# =============================================================================
# Security Module Variables (Refactored)
# =============================================================================
# 
# このファイルはSecurityモジュールの変数定義を含みます。
# 構造化されたセキュリティルール定義とベストプラクティスに沿った設計となっています。
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

variable "vpc_id" {
  description = "VPCのID"
  type        = string
  
  validation {
    condition     = can(regex("^vpc-[a-z0-9]{8,17}$", var.vpc_id))
    error_message = "有効なVPC IDを指定してください（vpc- で始まり、8-17文字の英数字である必要があります）。"
  }
}

# -----------------------------------------------------------------------------
# Security Rules Configuration
# -----------------------------------------------------------------------------

variable "security_rules" {
  description = "構造化されたセキュリティルール定義"
  type = object({
    # EC2 Public Security Group Rules
    ssh = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    http = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    https = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    icmp = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # EC2 Private Security Group Rules
    private_ssh = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    private_http = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    private_https = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # RDS Security Group Rules
    mysql = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    postgresql = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # NAT Instance Security Group Rules
    nat_ssh = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    nat_icmp = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # ALB Security Group Rules
    alb_http = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    alb_https = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # Cache Security Group Rules
    redis = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    memcached = object({
      enabled       = bool
      allowed_cidrs = list(string)
    })
    
    # Common Egress Rules
    egress = object({
      allowed_cidrs = list(string)
    })
  })
  
  default = {
    # EC2 Public Security Group Rules
    ssh = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    http = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    https = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    icmp = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    
    # EC2 Private Security Group Rules
    private_ssh = {
      enabled       = true
      allowed_cidrs = ["10.0.0.0/16"]
    }
    private_http = {
      enabled       = true
      allowed_cidrs = ["10.0.0.0/16"]
    }
    private_https = {
      enabled       = true
      allowed_cidrs = ["10.0.0.0/16"]
    }
    
    # RDS Security Group Rules
    mysql = {
      enabled       = true
      allowed_cidrs = []
    }
    postgresql = {
      enabled       = false
      allowed_cidrs = []
    }
    
    # NAT Instance Security Group Rules
    nat_ssh = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    nat_icmp = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    
    # ALB Security Group Rules
    alb_http = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    alb_https = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    
    # Cache Security Group Rules
    redis = {
      enabled       = false
      allowed_cidrs = []
    }
    memcached = {
      enabled       = false
      allowed_cidrs = []
    }
    
    # Common Egress Rules
    egress = {
      allowed_cidrs = ["0.0.0.0/0"]
    }
  }
  
  validation {
    condition = alltrue([
      # CIDRブロックの検証
      for rule in [
        var.security_rules.ssh,
        var.security_rules.http,
        var.security_rules.https,
        var.security_rules.icmp,
        var.security_rules.private_ssh,
        var.security_rules.private_http,
        var.security_rules.private_https,
        var.security_rules.mysql,
        var.security_rules.postgresql,
        var.security_rules.nat_ssh,
        var.security_rules.nat_icmp,
        var.security_rules.alb_http,
        var.security_rules.alb_https,
        var.security_rules.redis,
        var.security_rules.memcached,
        var.security_rules.egress
      ] : alltrue([
        for cidr in rule.allowed_cidrs : 
        can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
      ])
    ])
    error_message = "有効なCIDRブロックを指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Optional Security Groups
# -----------------------------------------------------------------------------

variable "enable_alb_security_group" {
  description = "ALBセキュリティグループの有効化"
  type        = bool
  default     = false
}

variable "enable_cache_security_group" {
  description = "キャッシュセキュリティグループの有効化"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Security Audit Configuration
# -----------------------------------------------------------------------------

variable "enable_security_audit" {
  description = "セキュリティ監査機能の有効化"
  type        = bool
  default     = false
}

variable "security_audit_retention_days" {
  description = "セキュリティ監査ログの保持期間（日数）"
  type        = number
  default     = 30
  
  validation {
    condition     = var.security_audit_retention_days >= 1 && var.security_audit_retention_days <= 365
    error_message = "保持期間は1日から365日の間で指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Custom Security Rules
# -----------------------------------------------------------------------------

variable "custom_security_rules" {
  description = "カスタムセキュリティルール"
  type = list(object({
    security_group_name = string
    description        = string
    port              = number
    protocol          = string
    cidr_blocks       = list(string)
    security_groups   = list(string)
    rule_type         = string # "ingress" or "egress"
    enabled           = bool
  }))
  default = []
  
  validation {
    condition = alltrue([
      for rule in var.custom_security_rules : 
      length(rule.description) > 0 &&
      rule.port >= -1 && rule.port <= 65535 &&
      contains(["tcp", "udp", "icmp", "-1"], rule.protocol) &&
      contains(["ingress", "egress"], rule.rule_type) &&
      alltrue([
        for cidr in rule.cidr_blocks : 
        can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
      ])
    ])
    error_message = "カスタムセキュリティルールの形式が正しくありません。"
  }
}

# -----------------------------------------------------------------------------
# Security Compliance Settings
# -----------------------------------------------------------------------------

variable "enable_security_compliance" {
  description = "セキュリティコンプライアンス機能の有効化"
  type        = bool
  default     = false
}

variable "compliance_standards" {
  description = "適用するコンプライアンス標準"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for standard in var.compliance_standards : 
      contains(["CIS", "NIST", "ISO27001", "SOC2"], standard)
    ])
    error_message = "サポートされているコンプライアンス標準は CIS, NIST, ISO27001, SOC2 です。"
  }
}

variable "security_notification_email" {
  description = "セキュリティ通知用メールアドレス"
  type        = string
  default     = ""
  
  validation {
    condition     = var.security_notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_notification_email))
    error_message = "有効なメールアドレスを指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Advanced Security Settings
# -----------------------------------------------------------------------------

variable "enable_security_monitoring" {
  description = "セキュリティ監視機能の有効化"
  type        = bool
  default     = false
}

variable "security_monitoring_interval" {
  description = "セキュリティ監視の実行間隔（分）"
  type        = number
  default     = 60
  
  validation {
    condition     = var.security_monitoring_interval >= 1 && var.security_monitoring_interval <= 1440
    error_message = "監視間隔は1分から1440分（24時間）の間で指定してください。"
  }
}

variable "enable_security_automation" {
  description = "セキュリティ自動化機能の有効化"
  type        = bool
  default     = false
}

variable "security_automation_actions" {
  description = "セキュリティ自動化で実行するアクション"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for action in var.security_automation_actions : 
      contains(["block_ip", "notify_admin", "create_incident", "isolate_instance"], action)
    ])
    error_message = "サポートされている自動化アクションは block_ip, notify_admin, create_incident, isolate_instance です。"
  }
}

# -----------------------------------------------------------------------------
# CloudFront Settings
# -----------------------------------------------------------------------------

variable "enable_cloudfront_access" {
  description = "CloudFrontアクセス用セキュリティグループの有効化"
  type        = bool
  default     = false
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