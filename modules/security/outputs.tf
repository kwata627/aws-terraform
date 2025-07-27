output "ec2_public_sg_id" {
  description = "EC2用セキュリティグループのID"
  value       = aws_security_group.ec2_public.id
}

output "rds_sg_id" {
  description = "RDS用セキュリティグループのID"
  value       = aws_security_group.rds.id
}

output "nat_sg_id" {
  description = "NAT Gateway用セキュリティグループのID"
  value       = aws_security_group.nat.id
}