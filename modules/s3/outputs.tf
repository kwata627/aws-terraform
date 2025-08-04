# =============================================================================
# S3 Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Bucket Information
# -----------------------------------------------------------------------------

output "bucket_id" {
  description = "作成したS3バケットのID"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "作成したS3バケットのARN"
  value       = aws_s3_bucket.main.arn
}

output "bucket_name" {
  description = "作成したS3バケットの名前"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_domain_name" {
  description = "S3バケットのドメイン名（CloudFrontオリジン用）"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_region" {
  description = "S3バケットのリージョン"
  value       = aws_s3_bucket.main.region
}

# -----------------------------------------------------------------------------
# Versioning Information
# -----------------------------------------------------------------------------

output "versioning_enabled" {
  description = "バージョニングの有効化状態"
  value       = var.enable_versioning
}

output "mfa_delete_enabled" {
  description = "MFA削除の有効化状態"
  value       = var.enable_mfa_delete
}

# -----------------------------------------------------------------------------
# Encryption Information
# -----------------------------------------------------------------------------

output "encryption_algorithm" {
  description = "使用されている暗号化アルゴリズム"
  value       = var.encryption_algorithm
}

output "bucket_key_enabled" {
  description = "バケットキーの有効化状態"
  value       = var.enable_bucket_key
}

output "kms_key_used" {
  description = "使用されているKMSキーID"
  value       = var.encryption_algorithm == "aws:kms" ? var.kms_key_id : null
}

# -----------------------------------------------------------------------------
# Public Access Information
# -----------------------------------------------------------------------------

output "public_access_blocked" {
  description = "パブリックアクセスのブロック状態"
  value = {
    block_public_acls       = var.block_public_acls
    block_public_policy     = var.block_public_policy
    ignore_public_acls      = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets
  }
}

output "object_ownership" {
  description = "オブジェクト所有権設定"
  value       = var.object_ownership
}

output "bucket_acl" {
  description = "バケットACL設定"
  value       = var.bucket_acl
}

# -----------------------------------------------------------------------------
# Lifecycle Management Information
# -----------------------------------------------------------------------------

output "lifecycle_management_enabled" {
  description = "ライフサイクル管理の有効化状態"
  value       = var.enable_lifecycle_management
}

output "object_expiration_enabled" {
  description = "オブジェクト自動削除の有効化状態"
  value       = var.enable_object_expiration
}

output "lifecycle_settings" {
  description = "ライフサイクル設定"
  value = {
    noncurrent_version_transition_days = var.noncurrent_version_transition_days
    noncurrent_version_storage_class   = var.noncurrent_version_storage_class
    noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
    abort_incomplete_multipart_days   = var.abort_incomplete_multipart_days
    object_expiration_days            = var.enable_object_expiration ? var.object_expiration_days : null
  }
}

# -----------------------------------------------------------------------------
# Access Logging Information
# -----------------------------------------------------------------------------

output "access_logging_enabled" {
  description = "アクセスログの有効化状態"
  value       = var.enable_access_logging
}

output "access_logs_bucket_id" {
  description = "アクセスログ用バケットのID"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "アクセスログ用バケットのARN"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].arn : null
}

# -----------------------------------------------------------------------------
# Inventory Information
# -----------------------------------------------------------------------------

output "inventory_enabled" {
  description = "インベントリの有効化状態"
  value       = var.enable_inventory
}

output "inventory_bucket_id" {
  description = "インベントリ用バケットのID"
  value       = var.enable_inventory ? aws_s3_bucket.inventory[0].id : null
}

output "inventory_bucket_arn" {
  description = "インベントリ用バケットのARN"
  value       = var.enable_inventory ? aws_s3_bucket.inventory[0].arn : null
}

# -----------------------------------------------------------------------------
# Intelligent Tiering Information
# -----------------------------------------------------------------------------

output "intelligent_tiering_enabled" {
  description = "インテリジェントティアリングの有効化状態"
  value       = var.enable_intelligent_tiering
}

output "tiering_settings" {
  description = "インテリジェントティアリング設定"
  value = var.enable_intelligent_tiering ? {
    archive_access_days      = var.archive_access_days
    deep_archive_access_days = var.deep_archive_access_days
  } : null
}

# -----------------------------------------------------------------------------
# CloudFront Integration
# -----------------------------------------------------------------------------

output "cloudfront_integration_enabled" {
  description = "CloudFront統合の有効化状態"
  value       = var.cloudfront_distribution_arn != ""
}

output "bucket_policy_created" {
  description = "バケットポリシーが作成されたかどうか"
  value       = var.cloudfront_distribution_arn != ""
}

# -----------------------------------------------------------------------------
# Summary Outputs
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "S3モジュールの設定サマリー"
  value = {
    bucket_name = aws_s3_bucket.main.bucket
    bucket_purpose = var.bucket_purpose
    environment = var.environment
    versioning_enabled = var.enable_versioning
    encryption_algorithm = var.encryption_algorithm
    lifecycle_management = var.enable_lifecycle_management
    access_logging = var.enable_access_logging
    inventory = var.enable_inventory
    intelligent_tiering = var.enable_intelligent_tiering
    cloudfront_integration = var.cloudfront_distribution_arn != ""
  }
}

output "security_features" {
  description = "有効化されているセキュリティ機能"
  value = {
    encryption = var.encryption_algorithm != ""
    public_access_blocked = var.block_public_acls && var.block_public_policy && var.ignore_public_acls && var.restrict_public_buckets
    versioning = var.enable_versioning
    mfa_delete = var.enable_mfa_delete
    bucket_key = var.enable_bucket_key
  }
}
