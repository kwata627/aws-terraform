# SSHモジュール（統一されたキーペア管理）
module "ssh" {
  source  = "./modules/ssh"
  project = var.project
}

# NATインスタンスモジュール
module "nat_instance" {
  source            = "./modules/nat-instance"
  project           = var.project
  subnet_id         = module.network.public_subnet_ids[0]
  security_group_id = module.security.nat_instance_sg_id
  ami_id            = var.ami_id
  instance_type     = "t3.nano"
  key_name          = module.ssh.key_name
  ssh_public_key    = module.ssh.public_key_openssh
  ssh_private_key   = module.ssh.private_key_pem
  environment       = "production"
  vpc_cidr          = var.vpc_cidr
}

# ネットワークモジュール
module "network" {
  source = "./modules/network"
  
  project  = var.project
  vpc_cidr = var.vpc_cidr
  
  # パブリックサブネット設定
  public_subnets = [
    {
      cidr = var.public_subnet_cidr
      az   = var.az1
    }
  ]
  
  # プライベートサブネット設定（RDS用に2つ作成）
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
  
  # NATインスタンス設定
  nat_instance_network_interface_id = module.nat_instance.nat_instance_network_interface_id
  enable_nat_route = true
  
  # セキュリティ設定
  enable_network_acls = false  # 必要に応じて有効化
  enable_vpc_endpoints = false # 必要に応じて有効化
  enable_flow_logs = false     # 必要に応じて有効化
  
  # 環境設定
  environment = "production"
  aws_region = "ap-northeast-1"
  
  # タグ設定
  tags = {
    Project     = var.project
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# セキュリティグループモジュール
module "security" {
  source   = "./modules/security"
  project  = var.project
  vpc_id   = module.network.vpc_id
}

# EC2モジュール
module "ec2" {
  source            = "./modules/ec2"
  project           = var.project
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.network.public_subnet_ids[0]
  private_subnet_id = module.network.private_subnet_ids[0]
  security_group_id = module.security.ec2_public_sg_id
  validation_security_group_id = module.security.ec2_private_sg_id
  key_name          = module.ssh.key_name
  ssh_public_key    = module.ssh.public_key_openssh
  ec2_name          = var.ec2_name
  enable_validation_ec2 = var.enable_validation_ec2
  validation_ec2_name = var.validation_ec2_name
  environment       = "production"
}

# RDSモジュール
module "rds" {
  source = "./modules/rds"
  
  project = var.project
  
  # ネットワーク設定
  private_subnet_ids = module.network.private_subnet_ids
  rds_security_group_id = module.security.rds_sg_id
  
  # データベース設定
  db_password = var.db_password
  snapshot_date = var.snapshot_date
  rds_identifier = var.rds_identifier
  
  # セキュリティ設定
  deletion_protection = false  # 必要に応じて有効化
  storage_encrypted = true
  publicly_accessible = false
  multi_az = false  # 必要に応じて有効化
  
  # バックアップ設定
  backup_retention_period = 7
  backup_window = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"
  
  # 監視・ログ設定
  enable_cloudwatch_logs = false     # 必要に応じて有効化
  enable_performance_insights = false # 必要に応じて有効化
  enable_enhanced_monitoring = false # 必要に応じて有効化
  
  # 検証環境設定
  enable_validation_rds = var.enable_validation_rds
  validation_rds_snapshot_identifier = var.validation_rds_snapshot_identifier
  
  # 環境設定
  environment = "production"
  
  # タグ設定
  tags = {
    Project     = var.project
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# S3モジュール
module "s3" {
  source = "./modules/s3"
  
  project = var.project
  environment = "production"
  bucket_name = var.s3_bucket_name
  bucket_purpose = "static-files"
  
  # セキュリティ設定
  enable_versioning = true
  encryption_algorithm = "AES256"
  enable_bucket_key = true
  
  # パブリックアクセス制御
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
  object_ownership = "BucketOwnerEnforced"
  bucket_acl = "private"
  
  # ライフサイクル管理
  enable_lifecycle_management = true
  noncurrent_version_transition_days = 30
  noncurrent_version_storage_class = "STANDARD_IA"
  noncurrent_version_expiration_days = 90
  abort_incomplete_multipart_days = 7
  enable_object_expiration = false
  
  # 監視・ログ設定
  enable_access_logging = false  # 必要に応じて有効化
  enable_inventory = false       # 必要に応じて有効化
  
  # インテリジェントティアリング
  enable_intelligent_tiering = false  # 必要に応じて有効化
  
  # CloudFront統合
  # cloudfront_distribution_arn = module.cloudfront.distribution_arn # 一時的に無効化
  
  # タグ設定
  tags = {
    Project     = var.project
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ACMモジュール
module "acm" {
  source      = "./modules/acm"
  project     = var.project
  domain_name = var.domain_name
  environment = "production"
  
  providers = {
    aws = aws.us_east_1
  }
}

# CloudFrontモジュール（一時的に無効化）
# module "cloudfront" {
#   source                = "./modules/cloudfront"
#   project               = var.project
#   origin_domain_name    = module.s3.bucket_domain_name
#   acm_certificate_arn   = module.acm.certificate_arn
# }

# Route53モジュール
module "route53" {
  source = "./modules/route53"
  
  project = var.project
  
  # ドメイン設定
  domain_name = var.domain_name
  wordpress_ip = module.ec2.public_ip
  # cloudfront_domain_name = module.cloudfront.domain_name # 一時的に無効化
  certificate_validation_records = module.acm.validation_records
  
  # ドメイン登録設定
  register_domain = var.register_domain
  registrant_info = var.registrant_info
  
  # セキュリティ設定
  enable_dnssec = false  # 必要に応じて有効化
  enable_query_logging = false  # 必要に応じて有効化
  
  # ヘルスチェック設定
  enable_health_checks = false  # 必要に応じて有効化
  
  # プライベートホストゾーン設定
  is_private_zone = false
  private_zone_vpc_ids = []
  
  # 環境設定
  environment = "production"
  
  # タグ設定
  tags = {
    Project     = var.project
    Environment = "production"
    ManagedBy   = "terraform"
  }
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}