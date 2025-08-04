# =============================================================================
# SSH Module Outputs (Refactored)
# =============================================================================
# 
# このファイルはSSHモジュールの出力定義を含みます。
# セキュアなSSHキーペア管理とセキュリティ機能に対応しています。
# =============================================================================

# -----------------------------------------------------------------------------
# SSH Key Information
# -----------------------------------------------------------------------------

output "key_name" {
  description = "SSHキーペア名"
  value       = aws_key_pair.ssh.key_name
}

output "key_id" {
  description = "SSHキーペアID"
  value       = aws_key_pair.ssh.id
}

output "key_fingerprint" {
  description = "SSHキーペアのフィンガープリント"
  value       = aws_key_pair.ssh.fingerprint
}

output "key_arn" {
  description = "SSHキーペアのARN"
  value       = aws_key_pair.ssh.arn
}

# -----------------------------------------------------------------------------
# SSH Key Content
# -----------------------------------------------------------------------------

output "private_key_pem" {
  description = "生成された秘密鍵（PEM形式）"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "生成された公開鍵（OpenSSH形式）"
  value       = tls_private_key.ssh.public_key_openssh
}

output "public_key_pem" {
  description = "生成された公開鍵（PEM形式）"
  value       = tls_private_key.ssh.public_key_pem
}

# -----------------------------------------------------------------------------
# SSH Key Configuration
# -----------------------------------------------------------------------------

output "key_algorithm" {
  description = "使用されたSSHキーのアルゴリズム"
  value       = local.ssh_key_config.algorithm
}

output "key_size" {
  description = "SSHキーのサイズ"
  value       = local.ssh_key_config.algorithm == "RSA" ? local.ssh_key_config.rsa_bits : local.ssh_key_config.ecdsa_curve
}

# -----------------------------------------------------------------------------
# Backup Resources
# -----------------------------------------------------------------------------

output "backup_bucket_name" {
  description = "SSHキーバックアップ用S3バケット名"
  value       = var.enable_backup ? aws_s3_bucket.ssh_backup[0].bucket : null
}

output "backup_bucket_arn" {
  description = "SSHキーバックアップ用S3バケットのARN"
  value       = var.enable_backup ? aws_s3_bucket.ssh_backup[0].arn : null
}

# -----------------------------------------------------------------------------
# Audit Resources
# -----------------------------------------------------------------------------

output "audit_log_group_name" {
  description = "SSHキー監査ロググループ名"
  value       = var.enable_audit_logs ? aws_cloudwatch_log_group.ssh_audit[0].name : null
}

output "audit_log_group_arn" {
  description = "SSHキー監査ロググループのARN"
  value       = var.enable_audit_logs ? aws_cloudwatch_log_group.ssh_audit[0].arn : null
}

# -----------------------------------------------------------------------------
# Rotation Resources
# -----------------------------------------------------------------------------

output "rotation_role_arn" {
  description = "SSHキーローテーション用IAMロールのARN"
  value       = var.enable_key_rotation ? aws_iam_role.ssh_rotation[0].arn : null
}

output "rotation_role_name" {
  description = "SSHキーローテーション用IAMロールの名前"
  value       = var.enable_key_rotation ? aws_iam_role.ssh_rotation[0].name : null
}

# -----------------------------------------------------------------------------
# Security Features Status
# -----------------------------------------------------------------------------

output "security_features_enabled" {
  description = "有効化されているセキュリティ機能"
  value = {
    key_rotation = var.enable_key_rotation
    backup = var.enable_backup
    audit_logs = var.enable_audit_logs
  }
}

output "security_config" {
  description = "セキュリティ設定"
  value = {
    algorithm = local.ssh_key_config.algorithm
    key_size = local.ssh_key_config.algorithm == "RSA" ? local.ssh_key_config.rsa_bits : local.ssh_key_config.ecdsa_curve
    rotation_days = var.key_rotation_days
    backup_retention_days = var.backup_retention_days
    audit_retention_days = var.audit_retention_days
  }
}

# -----------------------------------------------------------------------------
# Module Summary
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "SSHモジュールの設定サマリー"
  value = {
    project = var.project
    environment = var.environment
    key_name = aws_key_pair.ssh.key_name
    algorithm = local.ssh_key_config.algorithm
    key_size = local.ssh_key_config.algorithm == "RSA" ? local.ssh_key_config.rsa_bits : local.ssh_key_config.ecdsa_curve
    backup_enabled = var.enable_backup
    rotation_enabled = var.enable_key_rotation
    audit_enabled = var.enable_audit_logs
  }
} 