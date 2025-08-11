# =============================================================================
# SSH Module - Local Values
# =============================================================================
# 
# このファイルはSSHモジュールのローカル値定義を含みます。
# SSHキーペアの設定とタグ管理を効率的に行います。
# =============================================================================

locals {
  # 共通タグ
  common_tags = merge(
    {
      Name        = "${var.project}-ssh"
      Environment = var.environment
      Module      = "ssh"
      ManagedBy   = "terraform"
      Project     = var.project
      Security    = "high"
      Version     = "2.0.0"
    },
    var.tags
  )
  
  # SSHキーペア設定
  ssh_key_config = {
    name        = "${var.project}-${var.key_name_suffix}"
    description = "SSH key pair for ${var.project} project"
    algorithm   = var.key_algorithm
    rsa_bits    = var.rsa_bits
    ecdsa_curve = var.ecdsa_curve
  }
  
  # セキュリティ設定
  security_config = {
    enable_key_rotation = var.enable_key_rotation
    key_rotation_days   = var.key_rotation_days
    enable_backup       = var.enable_backup
    backup_retention_days = var.backup_retention_days
  }
  
  # 監査設定
  audit_config = {
    enable_audit_logs = var.enable_audit_logs
    audit_retention_days = var.audit_retention_days
  }
} 