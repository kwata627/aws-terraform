# =============================================================================
# EC2 Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Production Instance Information
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "作成したEC2インスタンスのID"
  value       = aws_instance.wordpress.id
}

output "instance_arn" {
  description = "EC2インスタンスのARN"
  value       = aws_instance.wordpress.arn
}

output "instance_state" {
  description = "EC2インスタンスの現在の状態"
  value       = aws_instance.wordpress.instance_state
}

output "public_ip" {
  description = "EC2インスタンスのパブリックIPアドレス"
  value       = aws_eip.wordpress.public_ip
}

output "public_dns" {
  description = "EC2インスタンスのパブリックDNS名"
  value       = aws_eip.wordpress.public_dns
}

output "private_ip" {
  description = "EC2インスタンスのプライベートIPアドレス"
  value       = aws_instance.wordpress.private_ip
}

output "private_dns" {
  description = "EC2インスタンスのプライベートDNS名"
  value       = aws_instance.wordpress.private_dns
}

# -----------------------------------------------------------------------------
# Instance Details
# -----------------------------------------------------------------------------

output "instance_type" {
  description = "EC2インスタンスタイプ"
  value       = aws_instance.wordpress.instance_type
}

output "availability_zone" {
  description = "EC2インスタンスのアベイラビリティゾーン"
  value       = aws_instance.wordpress.availability_zone
}

output "subnet_id" {
  description = "EC2インスタンスのサブネットID"
  value       = aws_instance.wordpress.subnet_id
}

output "vpc_security_group_ids" {
  description = "EC2インスタンスのセキュリティグループID"
  value       = aws_instance.wordpress.vpc_security_group_ids
}

# -----------------------------------------------------------------------------
# Storage Information
# -----------------------------------------------------------------------------

output "root_block_device" {
  description = "ルートボリュームの詳細情報"
  value = {
    volume_id   = aws_instance.wordpress.root_block_device[0].volume_id
    volume_size = aws_instance.wordpress.root_block_device[0].volume_size
    volume_type = aws_instance.wordpress.root_block_device[0].volume_type
    encrypted   = aws_instance.wordpress.root_block_device[0].encrypted
  }
}

# -----------------------------------------------------------------------------
# Validation Instance Information
# -----------------------------------------------------------------------------

output "validation_instance_id" {
  description = "検証用EC2インスタンスのID"
  value       = local.validation_enabled ? aws_instance.validation[0].id : null
}

output "validation_instance_state" {
  description = "検証用EC2インスタンスの現在の状態"
  value       = local.validation_enabled ? aws_instance.validation[0].instance_state : null
}

output "validation_private_ip" {
  description = "検証用EC2インスタンスのプライベートIPアドレス"
  value       = local.validation_enabled ? aws_instance.validation[0].private_ip : null
}

output "validation_private_dns" {
  description = "検証用EC2インスタンスのプライベートDNS名"
  value       = local.validation_enabled ? aws_instance.validation[0].private_dns : null
}

output "validation_instance_type" {
  description = "検証用EC2インスタンスタイプ"
  value       = local.validation_enabled ? aws_instance.validation[0].instance_type : null
}

output "validation_subnet_id" {
  description = "検証用EC2インスタンスのサブネットID"
  value       = local.validation_enabled ? aws_instance.validation[0].subnet_id : null
}

# -----------------------------------------------------------------------------
# Elastic IP Information
# -----------------------------------------------------------------------------

output "elastic_ip_id" {
  description = "Elastic IPのID"
  value       = aws_eip.wordpress.id
}

output "elastic_ip_arn" {
  description = "Elastic IPのARN"
  value       = aws_eip.wordpress.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

output "cloudwatch_alarms" {
  description = "CloudWatchアラームの情報"
  value = var.enable_cloudwatch_alarms ? {
    cpu_alarm_id = aws_cloudwatch_metric_alarm.cpu_high[0].id
    status_alarm_id = aws_cloudwatch_metric_alarm.status_check[0].id
  } : null
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
    production_instance = true
    validation_instance = local.validation_enabled
    elastic_ip          = true
    cloudwatch_alarms   = var.enable_cloudwatch_alarms
    detailed_monitoring = var.enable_detailed_monitoring
    imdsv2_required     = true
    volume_encryption   = var.root_volume_encrypted
  }
}

output "validation_enabled" {
  description = "検証環境が有効かどうか"
  value       = local.validation_enabled
}