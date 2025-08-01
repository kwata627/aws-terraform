output "ec2_public_sg_id" {
  description = "EC2用セキュリティグループのID"
  value       = aws_security_group.ec2_public.id
}

output "rds_sg_id" {
  description = "RDS用セキュリティグループのID"
  value       = aws_security_group.rds.id
}

output "nat_instance_sg_id" {
  description = "NATインスタンス用セキュリティグループID"
  value       = aws_security_group.nat_instance.id
}

output "ec2_private_sg_id" {
  description = "検証用EC2専用セキュリティグループID"
  value       = aws_security_group.ec2_private.id
}