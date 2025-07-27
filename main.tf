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
}