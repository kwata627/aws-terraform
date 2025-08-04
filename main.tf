# SSHモジュール（統一されたキーペア管理）
module "ssh" {
  source  = "./modules/ssh"
  project = var.project
}

# NATインスタンスモジュール
module "nat_instance" {
  source            = "./modules/nat-instance"
  project           = var.project
  subnet_id         = module.network.public_subnet_id
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
  source               = "./modules/network"
  project              = var.project
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  az1                  = var.az1
  nat_instance_network_interface_id = module.nat_instance.nat_instance_network_interface_id
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
  subnet_id         = module.network.public_subnet_id
  private_subnet_id = module.network.private_subnet_id_1
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
  source                  = "./modules/rds"
  project                 = var.project
  private_subnet_id_1     = module.network.private_subnet_id_1
  private_subnet_id_2     = module.network.private_subnet_id_2
  rds_security_group_id   = module.security.rds_sg_id
  db_password             = var.db_password
  snapshot_date           = var.snapshot_date
  rds_identifier          = var.rds_identifier
  enable_validation_rds   = var.enable_validation_rds
  validation_rds_snapshot_identifier = var.validation_rds_snapshot_identifier
}

# S3モジュール
module "s3" {
  source           = "./modules/s3"
  project          = var.project
  s3_bucket_name   = var.s3_bucket_name
  # cloudfront_distribution_arn = module.cloudfront.distribution_arn # 一時的に無効化
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
  source                        = "./modules/route53"
  project                       = var.project
  domain_name                   = var.domain_name
  wordpress_ip                  = module.ec2.public_ip
  # cloudfront_domain_name        = module.cloudfront.domain_name # 一時的に無効化
  certificate_validation_records = module.acm.validation_records
  registrant_info               = var.registrant_info
  register_domain               = var.register_domain
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}