output "instance_id" {
  description = "作成したEC2インスタンスのID"
  value       = aws_instance.wordpress.id
}

output "public_ip" {
  description = "EC2インスタンスのパブリックIPアドレス"
  value       = aws_eip.wordpress.public_ip
}

output "public_dns" {
  description = "EC2インスタンスのパブリックDNS名"
  value       = aws_eip.wordpress.public_dns
}

output "validation_instance_id" {
  description = "検証用EC2インスタンスのID"
  value       = var.enable_validation_ec2 ? aws_instance.validation[0].id : null
}

output "validation_private_ip" {
  description = "検証用EC2インスタンスのプライベートIPアドレス"
  value       = var.enable_validation_ec2 ? aws_instance.validation[0].private_ip : null
}