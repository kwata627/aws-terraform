# =============================================================================
# Main Terraform Configuration (Refactored)
# =============================================================================
# 
# このファイルはメインTerraform設定のモジュール定義を含みます。
# セキュアなインフラ設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# SSH Module (Unified Key Pair Management)
# -----------------------------------------------------------------------------

module "ssh" {
  source  = "./modules/ssh"
  project = var.project
  environment = local.environment_config.name
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# NAT Instance Module
# -----------------------------------------------------------------------------

module "nat_instance" {
  source            = "./modules/nat-instance"
  project           = var.project
  subnet_id         = module.network.public_subnet_ids[0]
  security_group_id = local.enable_security ? module.security[0].nat_instance_sg_id : null
  ami_id            = local.ec2_config.ami_id
  instance_type     = "t3.nano"
  key_name          = module.ssh.key_name
  ssh_public_key    = module.ssh.public_key_openssh
  ssh_private_key   = module.ssh.private_key_pem
  environment       = local.environment_config.name
  vpc_cidr          = local.network_config.vpc_cidr
}

# -----------------------------------------------------------------------------
# Network Module
# -----------------------------------------------------------------------------

module "network" {
  source = "./modules/network"
  
  project  = var.project
  vpc_cidr = local.network_config.vpc_cidr
  
  # パブリックサブネット設定
  public_subnets = local.network_config.public_subnets
  
  # プライベートサブネット設定（RDS用に2つ作成）
  private_subnets = local.network_config.private_subnets
  
  # NATインスタンス設定
  nat_instance_network_interface_id = module.nat_instance.nat_instance_network_interface_id
  enable_nat_route = local.network_features.enable_nat_route
  
  # セキュリティ設定
  enable_network_acls = local.network_features.enable_network_acls
  enable_vpc_endpoints = local.network_features.enable_vpc_endpoints
  enable_flow_logs = local.network_features.enable_flow_logs
  
  # 環境設定
  environment = local.environment_config.name
  aws_region = local.environment_config.region
  
  # タグ設定
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Security Module
# -----------------------------------------------------------------------------

locals {
  enable_security = var.vpc_cidr != ""
}

module "security" {
  source   = "./modules/security"
  project  = var.project
  vpc_id   = module.network.vpc_id
  
  # セキュリティルール設定
  security_rules = local.security_rules
  
  # セキュリティ機能設定
  enable_security_audit = local.security_features.enable_security_audit
  enable_security_monitoring = local.security_features.enable_security_monitoring
  enable_security_automation = local.security_features.enable_security_automation
  enable_security_compliance = local.security_features.enable_security_compliance
  
  # 環境設定
  environment = local.environment_config.name
  count = local.enable_security ? 1 : 0
}

# -----------------------------------------------------------------------------
# EC2 Module
# -----------------------------------------------------------------------------

module "ec2" {
  source            = "./modules/ec2"
  project           = var.project
  ami_id            = local.ec2_config.ami_id
  instance_type     = local.ec2_config.instance_type
  subnet_id         = module.network.public_subnet_ids[0]
  private_subnet_id = module.network.private_subnet_ids[0]
  security_group_id = local.enable_security ? module.security[0].ec2_public_sg_id : null
  validation_security_group_id = local.enable_security ? module.security[0].ec2_private_sg_id : null
  key_name          = module.ssh.key_name
  ssh_public_key    = module.ssh.public_key_openssh
  ec2_name          = local.ec2_config.ec2_name
  enable_validation_ec2 = local.ec2_config.enable_validation_ec2
  validation_ec2_name = local.ec2_config.validation_ec2_name
  environment       = local.environment_config.name
}

# -----------------------------------------------------------------------------
# RDS Module
# -----------------------------------------------------------------------------

module "rds" {
  source = "./modules/rds"
  
  project = var.project
  
  # ネットワーク設定
  private_subnet_ids = module.network.private_subnet_ids
  rds_security_group_id = local.enable_security ? module.security[0].rds_sg_id : null
  
  # データベース設定
  db_password = local.rds_config.db_password
  snapshot_date = local.rds_config.snapshot_date
  rds_identifier = local.rds_config.rds_identifier
  
  # セキュリティ設定
  deletion_protection = local.rds_features.deletion_protection
  storage_encrypted = local.rds_features.storage_encrypted
  publicly_accessible = local.rds_features.publicly_accessible
  multi_az = local.rds_features.multi_az
  
  # バックアップ設定
  backup_retention_period = 7
  backup_window = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"
  
  # 監視・ログ設定
  enable_cloudwatch_logs = local.rds_features.enable_cloudwatch_logs
  enable_performance_insights = local.rds_features.enable_performance_insights
  enable_enhanced_monitoring = local.rds_features.enable_enhanced_monitoring
  
  # 検証環境設定
  enable_validation_rds = local.rds_config.enable_validation_rds
  validation_rds_snapshot_identifier = local.rds_config.validation_rds_snapshot_identifier
  
  # 環境設定
  environment = local.environment_config.name
  
  # タグ設定
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Module
# -----------------------------------------------------------------------------

module "s3" {
  source = "./modules/s3"
  
  project = var.project
  environment = local.environment_config.name
  bucket_name = local.s3_config.bucket_name
  bucket_purpose = local.s3_config.bucket_purpose
  
  # セキュリティ設定
  enable_versioning = local.s3_features.enable_versioning
  encryption_algorithm = local.s3_features.encryption_algorithm
  enable_bucket_key = local.s3_features.enable_bucket_key
  
  # パブリックアクセス制御
  block_public_acls = local.s3_features.block_public_acls
  block_public_policy = local.s3_features.block_public_policy
  ignore_public_acls = local.s3_features.ignore_public_acls
  restrict_public_buckets = local.s3_features.restrict_public_buckets
  object_ownership = local.s3_features.object_ownership
  bucket_acl = local.s3_features.bucket_acl
  
  # ライフサイクル管理
  enable_lifecycle_management = local.s3_features.enable_lifecycle_management
  noncurrent_version_transition_days = 30
  noncurrent_version_storage_class = "STANDARD_IA"
  noncurrent_version_expiration_days = 90
  abort_incomplete_multipart_days = 7
  enable_object_expiration = false
  
  # 監視・ログ設定
  enable_access_logging = local.s3_features.enable_access_logging
  enable_inventory = local.s3_features.enable_inventory
  
  # インテリジェントティアリング
  enable_intelligent_tiering = local.s3_features.enable_intelligent_tiering
  
  # CloudFront統合
  # cloudfront_distribution_arn = module.cloudfront.distribution_arn # 一時的に無効化
  
  # タグ設定
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ACM Module
# -----------------------------------------------------------------------------

module "acm" {
  source      = "./modules/acm"
  project     = var.project
  domain_name = local.domain_config.domain_name
  environment = local.environment_config.name
  
  providers = {
    aws = aws.us_east_1
  }
}

# -----------------------------------------------------------------------------
# CloudFront Module (Temporarily Disabled)
# -----------------------------------------------------------------------------

# module "cloudfront" {
#   source                = "./modules/cloudfront"
#   project               = var.project
#   origin_domain_name    = module.s3.bucket_domain_name
#   acm_certificate_arn   = module.acm.certificate_arn
#   environment           = local.environment_config.name
#   tags                  = local.common_tags
# }

# -----------------------------------------------------------------------------
# Route53 Module
# -----------------------------------------------------------------------------

module "route53" {
  source = "./modules/route53"
  
  project = var.project
  
  # ドメイン設定
  domain_name = local.domain_config.domain_name
  wordpress_ip = module.ec2.public_ip
  # cloudfront_domain_name = module.cloudfront.domain_name # 一時的に無効化
  certificate_validation_records = module.acm.validation_records
  
  # ドメイン登録設定
  register_domain = local.domain_config.register_domain
  registrant_info = local.domain_config.registrant_info
  
  # セキュリティ設定
  enable_dnssec = local.route53_features.enable_dnssec
  enable_query_logging = local.route53_features.enable_query_logging
  
  # ヘルスチェック設定
  enable_health_checks = local.route53_features.enable_health_checks
  
  # プライベートホストゾーン設定
  is_private_zone = local.route53_features.is_private_zone
  private_zone_vpc_ids = local.route53_features.private_zone_vpc_ids
  
  # 環境設定
  environment = local.environment_config.name
  
  # タグ設定
  tags = local.common_tags
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}