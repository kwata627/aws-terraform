# =============================================================================
# Main Terraform Configuration (Refactored)
# =============================================================================
# 
# このファイルはメインTerraform設定のモジュール定義を含みます。
# セキュアなインフラ設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# Domain Analysis
# -----------------------------------------------------------------------------

# ドメインの新規/既存を判別するためのデータソース
data "external" "domain_analysis" {
  program = ["bash", "${path.module}/scripts/check_nameservers.sh", "-d", local.domain_config.domain_name, "-t"]
  
  # 環境変数を設定してTerraformモードを有効化
  query = {
    TERRAFORM_MODE = "true"
    DOMAIN_NAME = local.domain_config.domain_name
  }
}

# ローカル変数でドメイン分析結果を解析
locals {
  domain_analysis = data.external.domain_analysis.result
  should_use_existing_zone = false  # 強制再作成のため、既存ホストゾーンを使用しない
  should_register_domain = try(local.domain_analysis.should_register_domain, "false") == "true"
  domain_exists_in_route53 = try(local.domain_analysis.domain_exists_in_route53, "false") == "true"
  domain_exists_in_dns = try(local.domain_analysis.domain_exists_in_dns, "false") == "true"
  domain_registered = try(local.domain_analysis.domain_registered, "false") == "true"
}

# -----------------------------------------------------------------------------
# SSH Module (Unified Key Pair Management)
# -----------------------------------------------------------------------------

module "ssh" {
  source  = "./modules/ssh"
  project = var.project
  environment = local.environment_config.name
  key_name_suffix = var.ssh_key_name_suffix
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
  
  # CloudFront設定（無効化）
  enable_cloudfront_access = false
  
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
  security_group_ids = []  # CloudFrontアクセスセキュリティグループを削除
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
  
  # CloudFront統合（削除）
  # cloudfront_distribution_arn = module.cloudfront.distribution_arn
  
  # タグ設定
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ACM Module (無効化)
# -----------------------------------------------------------------------------

# module "acm" {
#   source      = "./modules/acm"
#   project     = var.project
#   domain_name = local.domain_config.domain_name
#   environment = local.environment_config.name
#   
#   # Route53ゾーンID（DNS検証用レコードの作成に必要）
#   route53_zone_id = module.route53.zone_id
#   
#   providers = {
#     aws = aws.us_east_1
#   }
#   
#   depends_on = [module.route53]
# }

# -----------------------------------------------------------------------------
# CloudFront Module (無効化)
# -----------------------------------------------------------------------------

# module "cloudfront" {
#   source                = "./modules/cloudfront"
#   project               = var.project
#   origin_domain_name    = module.ec2.public_dns
#   acm_certificate_arn   = module.acm.certificate_arn
#   aliases               = ["${local.domain_config.domain_name}", "cdn.${local.domain_config.domain_name}"]
#   environment           = local.environment_config.name
#   enable_wordpress_optimization = true
#   tags                  = local.common_tags
#   
#   depends_on = [module.acm, module.ec2]
# }

# -----------------------------------------------------------------------------
# Route53 Module
# -----------------------------------------------------------------------------

module "route53" {
  source = "./modules/route53"
  
  project = var.project
  
  # ドメイン設定
  domain_name = local.domain_config.domain_name
  wordpress_ip = module.ec2.public_ip  # 直接EC2を指す
  cloudfront_domain_name = ""  # CloudFrontを無効化
  
  # ドメイン登録設定（分析結果に基づいて決定）
  register_domain = local.should_register_domain
  registrant_info = local.domain_config.registrant_info
  
  # ドメイン分析結果
  should_use_existing_zone = local.should_use_existing_zone
  domain_exists_in_route53 = local.domain_exists_in_route53
  domain_exists_in_dns = local.domain_exists_in_dns
  domain_registered = local.domain_registered
  
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
  
  depends_on = [data.external.domain_analysis]
}

# -----------------------------------------------------------------------------
# CloudFront CNAME自動対処機能
# -----------------------------------------------------------------------------

# CloudFront CNAMEレコードの存在チェック（一時的に無効化）
# data "external" "cloudfront_cname_check" {
#   count = var.enable_cloudfront ? 1 : 0
#   
#   program = ["bash", "${path.module}/scripts/check_cloudfront_cname.sh"]
#   
#   query = {
#     domain_name = local.domain_config.domain_name
#     hosted_zone_id = module.route53.zone_id
#   }
#   
#   depends_on = [module.route53]
# }

# CloudFront CNAMEレコードの自動クリーンアップ（一時的に無効化）
# resource "null_resource" "cloudfront_cname_cleanup" {
#   count = var.enable_cloudfront && try(data.external.cloudfront_cname_check[0].result.needs_cleanup, false) ? 1 : 0
#   
#   triggers = {
#     domain_name = local.domain_config.domain_name
#     hosted_zone_id = module.route53.zone_id
#     record_value = try(data.external.cloudfront_cname_check[0].result.record_value, "")
#   }
#   
#   provisioner "local-exec" {
#     environment = {
#       DOMAIN_NAME = local.domain_config.domain_name
#       HOSTED_ZONE_ID = module.route53.zone_id
#       RECORD_VALUE = try(data.external.cloudfront_cname_check[0].result.record_value, "")
#     }
#     command = "${path.module}/scripts/cleanup_cloudfront_cname.sh"
#   }
#   
#   depends_on = [data.external.cloudfront_cname_check]
# }

# CloudFront CNAMEレコードの作成（CloudFrontディストリビューション作成後）
# 一時的に無効化
# resource "null_resource" "cloudfront_cname_creation" {
#   count = var.enable_cloudfront ? 1 : 0
#   
#   triggers = {
#     cloudfront_domain_name = module.cloudfront.domain_name
#     domain_name = local.domain_config.domain_name
#     hosted_zone_id = module.route53.zone_id
#   }
#   
#   provisioner "local-exec" {
#     environment = {
#       DOMAIN_NAME = local.domain_config.domain_name
#       HOSTED_ZONE_ID = module.route53.zone_id
#       CLOUDFRONT_DOMAIN_NAME = module.cloudfront.domain_name
#     }
#     command = "${path.module}/scripts/create_cloudfront_cname.sh"
#   }
#   
#   depends_on = [module.cloudfront]
# }

# Route53レコードの自動管理（直接EC2アクセス）
resource "aws_route53_record" "wordpress_main" {
  zone_id = module.route53.zone_id
  name    = local.domain_config.domain_name
  type    = "A"
  ttl     = 300
  records = [module.ec2.public_ip]

  depends_on = [module.ec2, module.route53]
}

# wwwサブドメインのRoute53レコード
resource "aws_route53_record" "wordpress_www" {
  zone_id = module.route53.zone_id
  name    = "www.${local.domain_config.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.ec2.public_ip]

  depends_on = [module.ec2, module.route53]
}

# 管理画面用の直接アクセスレコード
resource "aws_route53_record" "wordpress_direct" {
  zone_id = module.route53.zone_id
  name    = "admin.${local.domain_config.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.ec2.public_ip]

  depends_on = [module.ec2, module.route53]
}

# CloudFront関連レコードを削除
# resource "aws_route53_record" "cloudfront_cdn" {
#   count = var.enable_cloudfront ? 1 : 0
#   
#   zone_id = module.route53.zone_id
#   name    = "cdn.${local.domain_config.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
# 
#   records = [module.cloudfront.domain_name]
# 
#   depends_on = [module.cloudfront, module.route53]
# }

# CloudFrontキャッシュクリアを削除
# resource "null_resource" "cloudfront_cache_clear" {
#   count = var.enable_cloudfront ? 1 : 0
#   
#   triggers = {
#     wordpress_config = filemd5("${path.module}/ansible/roles/wordpress/templates/wp-config.php.j2")
#     htaccess_config = filemd5("${path.module}/ansible/roles/wordpress/templates/.htaccess.j2")
#     apache_config = filemd5("${path.module}/ansible/roles/apache/templates/wordpress.conf.j2")
#   }
#   
#   provisioner "local-exec" {
#     command = "aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths '/*'"
#   }
#   
#   depends_on = [module.cloudfront]
# }

# Ansible実行（WordPress設定適用）
# resource "null_resource" "ansible_wordpress_setup" {
#   triggers = {
#     ec2_instance = module.ec2.instance_id
#     wordpress_config = filemd5("${path.module}/ansible/roles/wordpress/templates/wp-config.php.j2")
#     apache_config = filemd5("${path.module}/ansible/roles/apache/templates/wordpress.conf.j2")
#     htaccess_config = filemd5("${path.module}/ansible/roles/wordpress/templates/.htaccess.j2")
#     apache_htaccess_config = filemd5("${path.module}/ansible/roles/apache/templates/wordpress.htaccess.j2")
#     php_config = filemd5("${path.module}/ansible/roles/php/templates/www.conf.j2")
#   }
#   
#   provisioner "local-exec" {
#     working_dir = "${path.module}/ansible"
#     environment = {
#       WORDPRESS_DB_HOST = module.rds.db_endpoint
#       WORDPRESS_DB_PASSWORD = var.db_password
#       WORDPRESS_DOMAIN = local.domain_config.domain_name
#       SSH_PRIVATE_KEY_PATH = module.ssh.private_key_path
#       SSH_PUBLIC_KEY_PATH = module.ssh.public_key_path
#       SSH_KEY_FILE_PATH = module.ssh.private_key_path
#       SSH_PUBLIC_KEY_FILE_PATH = module.ssh.public_key_path
#       WP_ADMIN_USER = "admin"
#       WP_ADMIN_PASSWORD = var.db_password
#     }
#     command = "python3 generate_inventory.py && ansible-playbook --config ansible.cfg -i inventory/hosts.yml playbooks/wordpress_setup.yml -v"
#   }
#   
#   depends_on = [module.ec2, module.rds, module.ssh]
# }

# -----------------------------------------------------------------------------
# ドメインネームサーバー自動更新機能
# -----------------------------------------------------------------------------

# ネームサーバー更新必要性チェック（一時的に無効化）
# data "external" "nameserver_update_check" {
#   count = var.auto_update_nameservers ? 1 : 0
#   
#   program = ["bash", "${path.module}/scripts/check_nameserver_update.sh"]
#   
#   query = {
#     domain_name = local.domain_config.domain_name
#     nameserver1 = module.route53.name_servers[0]
#     nameserver2 = module.route53.name_servers[1]
#     nameserver3 = module.route53.name_servers[2]
#     nameserver4 = module.route53.name_servers[3]
#   }
#   
#   depends_on = [module.route53]
# }

# ドメインネームサーバーの自動更新（一時的に無効化）
# resource "null_resource" "nameserver_update" {
#   count = var.auto_update_nameservers && try(data.external.nameserver_update_check[0].result.needs_update, false) ? 1 : 0
#   
#   triggers = {
#     domain_name = local.domain_config.domain_name
#     nameserver1 = module.route53.name_servers[0]
#     nameserver2 = module.route53.name_servers[1]
#     nameserver3 = module.route53.name_servers[2]
#     nameserver4 = module.route53.name_servers[3]
#   }
#   
#   provisioner "local-exec" {
#     environment = {
#       DOMAIN_NAME = local.domain_config.domain_name
#       NAMESERVER1 = module.route53.name_servers[0]
#       NAMESERVER2 = module.route53.name_servers[1]
#       NAMESERVER3 = module.route53.name_servers[2]
#       NAMESERVER4 = module.route53.name_servers[3]
#     }
#     command = "${path.module}/scripts/update_domain_nameservers.sh"
#   }
#   
#   depends_on = [data.external.nameserver_update_check]
# }