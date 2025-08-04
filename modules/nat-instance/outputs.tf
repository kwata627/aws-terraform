# =============================================================================
# NAT Instance Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Information
# -----------------------------------------------------------------------------

output "nat_instance_id" {
  description = "NATインスタンスのID"
  value       = aws_instance.nat.id
}

output "nat_instance_arn" {
  description = "NATインスタンスのARN"
  value       = aws_instance.nat.arn
}

output "nat_instance_state" {
  description = "NATインスタンスの現在の状態"
  value       = aws_instance.nat.instance_state
}

output "nat_instance_network_interface_id" {
  description = "NATインスタンスのネットワークインターフェースID"
  value       = aws_instance.nat.primary_network_interface_id
}

# -----------------------------------------------------------------------------
# Network Information
# -----------------------------------------------------------------------------

output "nat_public_ip" {
  description = "NATインスタンスのパブリックIPアドレス"
  value       = aws_eip.nat.public_ip
}

output "nat_public_dns" {
  description = "NATインスタンスのパブリックDNS名"
  value       = aws_eip.nat.public_dns
}

output "nat_private_ip" {
  description = "NATインスタンスのプライベートIPアドレス"
  value       = aws_instance.nat.private_ip
}

output "nat_private_dns" {
  description = "NATインスタンスのプライベートDNS名"
  value       = aws_instance.nat.private_dns
}

output "nat_subnet_id" {
  description = "NATインスタンスのサブネットID"
  value       = aws_instance.nat.subnet_id
}

output "nat_availability_zone" {
  description = "NATインスタンスのアベイラビリティゾーン"
  value       = aws_instance.nat.availability_zone
}

# -----------------------------------------------------------------------------
# Elastic IP Information
# -----------------------------------------------------------------------------

output "nat_eip_id" {
  description = "NATインスタンスに割り当てたEIPのID"
  value       = aws_eip.nat.id
}

output "nat_eip_arn" {
  description = "NATインスタンスに割り当てたEIPのARN"
  value       = aws_eip.nat.arn
}

output "nat_eip" {
  description = "NATインスタンスに割り当てたEIP"
  value       = aws_eip.nat.public_ip
}

# -----------------------------------------------------------------------------
# Storage Information
# -----------------------------------------------------------------------------

output "nat_root_block_device" {
  description = "NATインスタンスのルートボリューム詳細情報"
  value = {
    volume_id   = aws_instance.nat.root_block_device[0].volume_id
    volume_size = aws_instance.nat.root_block_device[0].volume_size
    volume_type = aws_instance.nat.root_block_device[0].volume_type
    encrypted   = aws_instance.nat.root_block_device[0].encrypted
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

output "cloudwatch_alarms" {
  description = "CloudWatchアラームの情報"
  value = var.enable_cloudwatch_alarms ? {
    cpu_alarm_id = aws_cloudwatch_metric_alarm.nat_cpu_high[0].id
    status_alarm_id = aws_cloudwatch_metric_alarm.nat_status_check[0].id
  } : null
}

# -----------------------------------------------------------------------------
# Network Interface (Optional)
# -----------------------------------------------------------------------------

output "network_interface_id" {
  description = "NATインスタンスのネットワークインターフェースID（オプション）"
  value       = var.enable_network_interface ? aws_network_interface.nat[0].id : null
}

output "network_interface_private_ip" {
  description = "NATインスタンスのネットワークインターフェースのプライベートIP（オプション）"
  value       = var.enable_network_interface ? aws_network_interface.nat[0].private_ip : null
}

# -----------------------------------------------------------------------------
# Module Information
# -----------------------------------------------------------------------------

output "module_version" {
  description = "モジュールのバージョン情報"
  value       = "1.0.0"
}

output "module_features" {
  description = "モジュールの機能一覧"
  value = {
    nat_instance = true
    elastic_ip = true
    cloudwatch_alarms = var.enable_cloudwatch_alarms
    detailed_monitoring = var.enable_detailed_monitoring
    imdsv2_required = true
    volume_encryption = var.root_volume_encrypted
    network_interface = var.enable_network_interface
  }
}

output "nat_configuration" {
  description = "NAT設定の詳細情報"
  value = {
    vpc_cidr = var.vpc_cidr
    instance_type = var.instance_type
    environment = var.environment
    high_availability = local.high_availability_enabled
  }
} 