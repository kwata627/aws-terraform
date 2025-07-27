output "vpc_id" {
  description = "このモジュールで作成したVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "パブリックサブネットのID"
  value       = aws_subnet.public_1a.id
}

output "private_subnet_id_1" {
  description = "プライベートサブネット1aのID"
  value       = aws_subnet.private_1a.id
}

output "private_subnet_id_2" {
  description = "プライベートサブネット1cのID"
  value       = aws_subnet.private_1c.id
}