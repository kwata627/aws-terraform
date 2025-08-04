# =============================================================================
# Network Module Outputs
# =============================================================================

output "vpc_id" {
  description = "作成されたVPCのID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "VPCのARN"
  value       = aws_vpc.main.arn
}

output "internet_gateway_id" {
  description = "Internet GatewayのID"
  value       = aws_internet_gateway.igw.id
}

output "public_subnet_ids" {
  description = "パブリックサブネットのID一覧"
  value       = aws_subnet.public[*].id
}

output "public_subnet_arns" {
  description = "パブリックサブネットのARN一覧"
  value       = aws_subnet.public[*].arn
}

output "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  value       = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  description = "プライベートサブネットのARN一覧"
  value       = aws_subnet.private[*].arn
}

output "public_route_table_id" {
  description = "パブリックルートテーブルのID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "プライベートルートテーブルのID"
  value       = aws_route_table.private.id
}

output "network_acl_ids" {
  description = "Network ACLのID一覧（有効な場合）"
  value       = var.enable_network_acls ? [aws_network_acl.public[0].id, aws_network_acl.private[0].id] : []
}

output "vpc_endpoint_ids" {
  description = "VPCエンドポイントのID一覧（有効な場合）"
  value       = var.enable_vpc_endpoints ? [aws_vpc_endpoint.s3[0].id, aws_vpc_endpoint.dynamodb[0].id] : []
}

output "flow_log_id" {
  description = "VPC Flow LogのID（有効な場合）"
  value       = var.enable_flow_logs ? aws_flow_log.vpc[0].id : null
}

# 後方互換性のための出力（非推奨）
output "public_subnet_id" {
  description = "最初のパブリックサブネットのID（後方互換性）"
  value       = length(aws_subnet.public) > 0 ? aws_subnet.public[0].id : null
}

output "private_subnet_id_1" {
  description = "最初のプライベートサブネットのID（後方互換性）"
  value       = length(aws_subnet.private) > 0 ? aws_subnet.private[0].id : null
}

output "private_subnet_id_2" {
  description = "2番目のプライベートサブネットのID（後方互換性）"
  value       = length(aws_subnet.private) > 1 ? aws_subnet.private[1].id : null
}