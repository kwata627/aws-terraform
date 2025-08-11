# =============================================================================
# Security Module - Local Values
# =============================================================================
# 
# このファイルはSecurityモジュールのローカル値定義を含みます。
# セキュリティグループの設定とタグ管理を効率的に行います。
# =============================================================================

locals {
  # 共通タグ
  common_tags = merge(
    {
      Name        = "${var.project}-security"
      Environment = var.environment
      Module      = "security"
      ManagedBy   = "terraform"
      Project     = var.project
      Security    = "high"
      Version     = "2.0.0"
    },
    var.tags
  )
  
  # セキュリティグループ定義
  security_groups = {
    ec2_public = {
      name        = "${var.project}-sg-ec2-public"
      description = "EC2 public subnet security group"
      rules = {
        ingress = [
          {
            description = "SSH"
            port        = 22
            protocol    = "tcp"
            cidr_blocks = var.security_rules.ssh.allowed_cidrs
            enabled     = var.security_rules.ssh.enabled
          },
          {
            description = "HTTP"
            port        = 80
            protocol    = "tcp"
            cidr_blocks = var.security_rules.http.allowed_cidrs
            enabled     = var.security_rules.http.enabled
          },
          {
            description = "HTTPS"
            port        = 443
            protocol    = "tcp"
            cidr_blocks = var.security_rules.https.allowed_cidrs
            enabled     = var.security_rules.https.enabled
          },
          {
            description = "ICMP"
            port        = -1
            protocol    = "icmp"
            cidr_blocks = var.security_rules.icmp.allowed_cidrs
            enabled     = var.security_rules.icmp.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    }
    
    ec2_private = {
      name        = "${var.project}-sg-ec2-private"
      description = "EC2 private subnet security group for validation"
      rules = {
        ingress = [
          {
            description = "SSH from public EC2"
            port        = 22
            protocol    = "tcp"
            cidr_blocks = var.security_rules.private_ssh.allowed_cidrs
            security_groups = ["ec2_public"]
            enabled     = var.security_rules.private_ssh.enabled
          },
          {
            description = "HTTP"
            port        = 80
            protocol    = "tcp"
            cidr_blocks = var.security_rules.private_http.allowed_cidrs
            enabled     = var.security_rules.private_http.enabled
          },
          {
            description = "HTTPS"
            port        = 443
            protocol    = "tcp"
            cidr_blocks = var.security_rules.private_https.allowed_cidrs
            enabled     = var.security_rules.private_https.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    }
    
    rds = {
      name        = "${var.project}-sg-rds"
      description = "RDS private subnet security group"
      rules = {
        ingress = [
          {
            description = "MySQL from EC2"
            port        = 3306
            protocol    = "tcp"
            cidr_blocks = var.security_rules.mysql.allowed_cidrs
            security_groups = ["ec2_public"]
            enabled     = var.security_rules.mysql.enabled
          },
          {
            description = "PostgreSQL from EC2"
            port        = 5432
            protocol    = "tcp"
            cidr_blocks = var.security_rules.postgresql.allowed_cidrs
            security_groups = ["ec2_public"]
            enabled     = var.security_rules.postgresql.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    }
    
    nat_instance = {
      name        = "${var.project}-sg-nat-instance"
      description = "NAT instance security group"
      rules = {
        ingress = [
          {
            description = "SSH"
            port        = 22
            protocol    = "tcp"
            cidr_blocks = var.security_rules.nat_ssh.allowed_cidrs
            enabled     = var.security_rules.nat_ssh.enabled
          },
          {
            description = "ICMP"
            port        = -1
            protocol    = "icmp"
            cidr_blocks = var.security_rules.nat_icmp.allowed_cidrs
            enabled     = var.security_rules.nat_icmp.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    }
  }
  
  # オプションセキュリティグループ
  optional_security_groups = {
    alb = var.enable_alb_security_group ? {
      name        = "${var.project}-sg-alb"
      description = "Application Load Balancer security group"
      rules = {
        ingress = [
          {
            description = "HTTP"
            port        = 80
            protocol    = "tcp"
            cidr_blocks = var.security_rules.alb_http.allowed_cidrs
            enabled     = var.security_rules.alb_http.enabled
          },
          {
            description = "HTTPS"
            port        = 443
            protocol    = "tcp"
            cidr_blocks = var.security_rules.alb_https.allowed_cidrs
            enabled     = var.security_rules.alb_https.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    } : null
    
    cache = var.enable_cache_security_group ? {
      name        = "${var.project}-sg-cache"
      description = "Cache security group (Redis/Memcached)"
      rules = {
        ingress = [
          {
            description = "Redis"
            port        = 6379
            protocol    = "tcp"
            cidr_blocks = var.security_rules.redis.allowed_cidrs
            security_groups = ["ec2_public"]
            enabled     = var.security_rules.redis.enabled
          },
          {
            description = "Memcached"
            port        = 11211
            protocol    = "tcp"
            cidr_blocks = var.security_rules.memcached.allowed_cidrs
            security_groups = ["ec2_public"]
            enabled     = var.security_rules.memcached.enabled
          }
        ]
        egress = [
          {
            description = "All outbound traffic"
            port        = 0
            protocol    = "-1"
            cidr_blocks = var.security_rules.egress.allowed_cidrs
          }
        ]
      }
    } : null
  }
  
  # セキュリティグループ参照マップ（循環参照を避けるため、動的に参照）
  security_group_refs = {
    ec2_public = "ec2_public"
    ec2_private = "ec2_private"
    rds = "rds"
    nat_instance = "nat_instance"
    alb = "alb"
    cache = "cache"
  }
  
  # セキュリティリスク評価
  security_risks = {
    high_risk_indicators = {
      public_ssh_access = var.security_rules.ssh.enabled && contains(var.security_rules.ssh.allowed_cidrs, "0.0.0.0/0")
      public_http_access = var.security_rules.http.enabled && contains(var.security_rules.http.allowed_cidrs, "0.0.0.0/0")
      public_https_access = var.security_rules.https.enabled && contains(var.security_rules.https.allowed_cidrs, "0.0.0.0/0")
      nat_public_access = var.security_rules.nat_ssh.enabled && contains(var.security_rules.nat_ssh.allowed_cidrs, "0.0.0.0/0")
      rds_public_access = var.security_rules.mysql.enabled && length(var.security_rules.mysql.allowed_cidrs) > 0
    }
    security_controls = {
      security_audit_enabled = var.enable_security_audit
      security_monitoring_enabled = var.enable_security_monitoring
      security_automation_enabled = var.enable_security_automation
      compliance_standards_applied = length(var.compliance_standards) > 0
    }
  }
} 