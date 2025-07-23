module "network" {
	source               = "./modules/network"
	project              = var.project
	vpc_cidr             = var.vpc_cidr
	public_subnet_cidr   = var.public_subnet_cidr
	private_subnet_cidr  = var.private_subnet_cidr
	az1                  = var.az1
}
