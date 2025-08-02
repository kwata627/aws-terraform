# WordPress EC2インスタンスの情報
output "wordpress_public_ip" {
  description = "WordPress EC2インスタンスのパブリックIP"
  value       = module.ec2.public_ip
}

output "wordpress_public_dns" {
  description = "WordPress EC2インスタンスのパブリックDNS"
  value       = module.ec2.public_dns
}

# NATインスタンスの情報
output "nat_instance_public_ip" {
  description = "NATインスタンスのパブリックIP"
  value       = module.nat_instance.nat_eip
}

# RDSの情報
output "rds_endpoint" {
  description = "RDSエンドポイント"
  value       = module.rds.db_endpoint
}

# Route53の情報
output "name_servers" {
  description = "Route53ネームサーバー"
  value       = module.route53.name_servers
}

# SSH鍵の情報
output "ssh_private_key" {
  description = "生成されたRSA秘密鍵（PEM形式）"
  value       = module.ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "生成されたRSA公開鍵（OpenSSH形式）"
  value       = module.ssh.public_key_openssh
}

# 検証用EC2インスタンスの情報
output "validation_private_ip" {
  description = "検証用EC2インスタンスのプライベートIP"
  value       = module.ec2.validation_private_ip
}
