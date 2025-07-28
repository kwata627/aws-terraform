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