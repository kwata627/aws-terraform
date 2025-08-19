# =============================================================================
# Main Terraform Configuration - Local Values (Optimized)
# =============================================================================
# 
# このファイルはメインTerraform設定のローカル値定義を含みます。
# 共通設定とタグ管理を効率的に行います。
# =============================================================================

locals {
  # 共通タグ
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Version     = "2.0.0"
    },
    var.tags
  )

  # 環境設定
  environment_config = {
    name    = var.environment
    region  = var.aws_region
    profile = var.aws_profile
  }

  # 自動リソース名生成（効率化）
  resource_names = {
    # EC2関連
    ec2_name            = coalesce(var.ec2_name, "${var.project}-ec2")
    validation_ec2_name = coalesce(var.validation_ec2_name, "${var.project}-test-ec2")

    # RDS関連
    rds_identifier            = coalesce(var.rds_identifier, "${var.project}-rds")
    validation_rds_identifier = "${var.project}-rds-validation"

    # S3関連
    s3_bucket_name = coalesce(var.s3_bucket_name, "${var.project}-s3")
  }

  # ネットワーク設定
  network_config = {
    vpc_cidr = var.vpc_cidr
    public_subnets = [
      {
        cidr = var.public_subnet_cidr
        az   = var.az1
      }
    ]
    private_subnets = [
      {
        cidr = var.private_subnet_cidr
        az   = var.az1
      },
      {
        cidr = "10.0.3.0/24"     # 2番目のプライベートサブネット
        az   = "ap-northeast-1c" # 異なるAZ
      }
    ]
  }

  # セキュリティルール設定（必要最小限）
  security_rules = {
    ssh = {
      enabled       = true
      allowed_cidrs = [var.ssh_allowed_cidr]
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
    private_ssh = {
      enabled       = true
      allowed_cidrs = [var.vpc_cidr]
    }
    private_http = {
      enabled       = true
      allowed_cidrs = [var.vpc_cidr]
    }
    private_https = {
      enabled       = true
      allowed_cidrs = [var.vpc_cidr]
    }
    mysql = {
      enabled       = true
      allowed_cidrs = []
    }
    postgresql = {
      enabled       = false
      allowed_cidrs = []
    }
    nat_ssh = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    nat_icmp = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    alb_http = {
      enabled       = false
      allowed_cidrs = ["0.0.0.0/0"]
    }
    alb_https = {
      enabled       = false
      allowed_cidrs = ["0.0.0.0/0"]
    }
    redis = {
      enabled       = false
      allowed_cidrs = []
    }
    memcached = {
      enabled       = false
      allowed_cidrs = []
    }
    egress = {
      allowed_cidrs = ["0.0.0.0/0"]
    }
  }

  # EC2設定
  ec2_config = {
    ami_id                = var.ami_id
    instance_type         = var.instance_type
    ec2_name              = local.resource_names.ec2_name
    validation_ec2_name   = local.resource_names.validation_ec2_name
    enable_validation_ec2 = var.enable_validation_ec2
  }

  # RDS設定
  rds_config = {
    rds_identifier                     = local.resource_names.rds_identifier
    db_password                        = var.db_password
    snapshot_date                      = var.snapshot_date
    enable_validation_rds              = var.enable_validation_rds
    validation_rds_snapshot_identifier = var.validation_rds_snapshot_identifier
  }

  # S3設定
  s3_config = {
    bucket_name    = local.resource_names.s3_bucket_name
    bucket_purpose = "static-files"
  }

  # ドメイン設定
  domain_config = {
    domain_name     = var.domain_name
    register_domain = var.register_domain
    registrant_info = var.registrant_info
  }

  # 機能設定（必要最小限に統合）
  features = {
    # セキュリティ機能
    security_audit      = false
    security_monitoring = false
    security_automation = false
    security_compliance = false

    # ネットワーク機能
    network_acls  = false
    vpc_endpoints = false
    flow_logs     = false
    nat_route     = true

    # RDS機能
    rds_deletion_protection  = false
    rds_storage_encrypted    = true
    rds_publicly_accessible  = false
    rds_multi_az             = false
    rds_cloudwatch_logs      = false
    rds_performance_insights = false
    rds_enhanced_monitoring  = false

    # S3機能
    s3_versioning            = true
    s3_encryption_algorithm  = "AES256"
    s3_bucket_key            = true
    s3_public_access_blocked = true
    s3_object_ownership      = "BucketOwnerEnforced"
    s3_lifecycle_management  = true
    s3_access_logging        = false
    s3_inventory             = false
    s3_intelligent_tiering   = false

    # Route53機能
    route53_dnssec               = false
    route53_query_logging        = false
    route53_health_checks        = false
    route53_private_zone         = false
    route53_private_zone_vpc_ids = []
  }
} 