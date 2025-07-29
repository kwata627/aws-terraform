# ネットワークモジュール
module "network" {
	source               = "./modules/network"
	project              = var.project
	vpc_cidr             = var.vpc_cidr
	public_subnet_cidr   = var.public_subnet_cidr
	private_subnet_cidr  = var.private_subnet_cidr
	az1                  = var.az1
}

# セキュリティグループモジュール
module "security" {
  source   = "./modules/security"
  project  = var.project
  vpc_id   = module.network.vpc_id
}

# RDSモジュール
module "rds" {
  source                = "./modules/rds"
  project               = var.project
  private_subnet_id_1   = module.network.private_subnet_id_1
  private_subnet_id_2   = module.network.private_subnet_id_2
  rds_security_group_id = module.security.rds_sg_id
  db_password           = var.db_password
  snapshot_date         = var.snapshot_date
  rds_identifier        = var.rds_identifier
}

# EC2モジュール
module "ec2" {
  source            = "./modules/ec2"
  project           = var.project
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.security.ec2_public_sg_id
  ssh_public_key    = var.ssh_public_key
  ec2_name          = var.ec2_name
}

# S3モジュール
module "s3" {
  source           = "./modules/s3"
  project          = var.project
  s3_bucket_name   = var.s3_bucket_name
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

# ACMモジュール
module "acm" {
  source      = "./modules/acm"
  project     = var.project
  domain_name = var.domain_name
}

# CloudFrontモジュール
module "cloudfront" {
  source                = "./modules/cloudfront"
  project               = var.project
  origin_domain_name    = module.s3.bucket_domain_name
  acm_certificate_arn   = module.acm.certificate_arn
}

# Route53モジュール
module "route53" {
  source                        = "./modules/route53"
  project                       = var.project
  domain_name                   = var.domain_name
  wordpress_ip                  = module.ec2.public_ip
  cloudfront_domain_name        = module.cloudfront.domain_name
  certificate_validation_records = module.acm.validation_records
}