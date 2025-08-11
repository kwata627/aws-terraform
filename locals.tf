# =============================================================================
# Main Terraform Configuration - Local Values
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
    name = var.environment
    region = var.aws_region
    profile = var.aws_profile
  }
  
  # 自動リソース名生成
  # 手動で値が指定された場合はその値を使用し、空の場合はproject名をprefixとして使用
  resource_names = {
    # EC2関連
    ec2_name = coalesce(var.ec2_name, "${var.project}-ec2")
    validation_ec2_name = coalesce(var.validation_ec2_name, "${var.project}-test-ec2")
    
    # RDS関連
    rds_identifier = coalesce(var.rds_identifier, "${var.project}-rds")
    validation_rds_identifier = "${var.project}-rds-validation"
    
    # S3関連
    s3_bucket_name = coalesce(var.s3_bucket_name, "${var.project}-s3")
    
    # セキュリティグループ関連
    sg_wordpress = "${var.project}-sg-wordpress"
    sg_rds = "${var.project}-sg-rds"
    sg_nat = "${var.project}-sg-nat"
    sg_alb = "${var.project}-sg-alb"
    
    # その他
    key_pair_name = "${var.project}-key"
    nat_instance_name = "${var.project}-nat"
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
        cidr = "10.0.3.0/24"  # 2番目のプライベートサブネット
        az   = "ap-northeast-1c"  # 異なるAZ
      }
    ]
  }
  
  # セキュリティルール設定
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
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    alb_https = {
      enabled       = true
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
    ami_id = var.ami_id
    instance_type = var.instance_type
    ec2_name = local.resource_names.ec2_name
    validation_ec2_name = local.resource_names.validation_ec2_name
    enable_validation_ec2 = var.enable_validation_ec2
  }
  
  # RDS設定
  rds_config = {
    rds_identifier = local.resource_names.rds_identifier
    db_password = var.db_password
    snapshot_date = var.snapshot_date
    enable_validation_rds = var.enable_validation_rds
    validation_rds_snapshot_identifier = var.validation_rds_snapshot_identifier
  }
  
  # S3設定
  s3_config = {
    bucket_name = local.resource_names.s3_bucket_name
    bucket_purpose = "static-files"
  }
  
  # ドメイン設定
  domain_config = {
    domain_name = var.domain_name
    register_domain = var.register_domain
    registrant_info = var.registrant_info
  }
  
  # セキュリティ機能設定
  security_features = {
    enable_security_audit = false
    enable_security_monitoring = false
    enable_security_automation = false
    enable_security_compliance = false
  }
  
  # ネットワーク機能設定
  network_features = {
    enable_network_acls = false
    enable_vpc_endpoints = false
    enable_flow_logs = false
    enable_nat_route = true
  }
  
  # RDS機能設定
  rds_features = {
    deletion_protection = false
    storage_encrypted = true
    publicly_accessible = false
    multi_az = false
    enable_cloudwatch_logs = false
    enable_performance_insights = false
    enable_enhanced_monitoring = false
  }
  
  # S3機能設定
  s3_features = {
    enable_versioning = true
    encryption_algorithm = "AES256"
    enable_bucket_key = true
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
    object_ownership = "BucketOwnerEnforced"
    bucket_acl = null
    enable_lifecycle_management = true
    enable_access_logging = false
    enable_inventory = false
    enable_intelligent_tiering = false
  }
  
  # Route53機能設定
  route53_features = {
    enable_dnssec = false
    enable_query_logging = false
    enable_health_checks = false
    is_private_zone = false
    private_zone_vpc_ids = []
  }
} 