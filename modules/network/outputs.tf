output "vpc_id" {
  description = "作成したVPCのID"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "パブリックサブネットのID"
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "プライベートサブネットのID"
  value       = module.network.private_subnet_id
}
