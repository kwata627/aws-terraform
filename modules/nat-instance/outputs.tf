output "nat_instance_id" {
  description = "NATインスタンスのID"
  value       = aws_instance.nat.id
}

output "nat_instance_network_interface_id" {
  description = "NATインスタンスのネットワークインターフェースID"
  value       = aws_instance.nat.primary_network_interface_id
}

output "nat_eip" {
  description = "NATインスタンスに割り当てたEIP"
  value       = aws_eip.nat.public_ip
} 