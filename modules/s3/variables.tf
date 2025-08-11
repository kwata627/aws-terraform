# =============================================================================
# S3 Module Variables
# =============================================================================

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "プロジェクト名は小文字、数字、ハイフンのみ使用可能です。"
  }
}

variable "environment" {
  description = "環境名（production, staging, development等）"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production", "staging", "development", "test"], var.environment)
    error_message = "環境名は production, staging, development, test のいずれかである必要があります。"
  }
}

variable "bucket_name" {
  description = "S3バケット名（suffixは自動付与）"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name))
    error_message = "バケット名は小文字、数字、ハイフンのみ使用可能です。"
  }
}

variable "bucket_purpose" {
  description = "バケットの用途"
  type        = string
  default     = "static-files"
  
  validation {
    condition     = contains(["static-files", "logs", "backup", "data", "media"], var.bucket_purpose)
    error_message = "バケットの用途は static-files, logs, backup, data, media のいずれかである必要があります。"
  }
}

variable "cloudfront_distribution_arn" {
  description = "CloudFrontディストリビューションのARN（S3バケットポリシー用）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.cloudfront_distribution_arn == "" || can(regex("^arn:aws:cloudfront::[0-9]+:distribution/[A-Z0-9]+$", var.cloudfront_distribution_arn))
    error_message = "有効なCloudFrontディストリビューションARNを指定してください。"
  }
}

# -----------------------------------------------------------------------------
# Versioning and Encryption Settings
# -----------------------------------------------------------------------------

variable "enable_versioning" {
  description = "バケットバージョニングの有効化"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "MFA削除の有効化"
  type        = bool
  default     = false
}

variable "encryption_algorithm" {
  description = "サーバーサイド暗号化アルゴリズム"
  type        = string
  default     = "AES256"
  
  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_algorithm)
    error_message = "暗号化アルゴリズムは AES256 または aws:kms である必要があります。"
  }
}

variable "kms_key_id" {
  description = "KMSキーID（aws:kms使用時）"
  type        = string
  default     = ""
  
  validation {
    condition     = var.kms_key_id == "" || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]+:key/[a-f0-9-]+$", var.kms_key_id))
    error_message = "有効なKMSキーARNを指定してください。"
  }
}

variable "enable_bucket_key" {
  description = "バケットキーの有効化"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Public Access Settings
# -----------------------------------------------------------------------------

variable "block_public_acls" {
  description = "パブリックACLのブロック"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "パブリックポリシーのブロック"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "パブリックACLの無視"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "パブリックバケットの制限"
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "オブジェクト所有権設定"
  type        = string
  default     = "BucketOwnerEnforced"
  
  validation {
    condition     = contains(["BucketOwnerPreferred", "ObjectWriter", "BucketOwnerEnforced"], var.object_ownership)
    error_message = "オブジェクト所有権は BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced のいずれかである必要があります。"
  }
}

variable "bucket_acl" {
  description = "バケットACL"
  type        = string
  default     = null
  
  validation {
    condition     = var.bucket_acl == null || contains(["private", "public-read", "public-read-write", "authenticated-read"], var.bucket_acl)
    error_message = "バケットACLは null または private, public-read, public-read-write, authenticated-read のいずれかである必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle Management
# -----------------------------------------------------------------------------

variable "enable_lifecycle_management" {
  description = "ライフサイクル管理の有効化"
  type        = bool
  default     = true
}

variable "noncurrent_version_transition_days" {
  description = "非現行バージョンの移行日数"
  type        = number
  default     = 30
  
  validation {
    condition     = var.noncurrent_version_transition_days >= 0
    error_message = "非現行バージョンの移行日数は0以上である必要があります。"
  }
}

variable "noncurrent_version_storage_class" {
  description = "非現行バージョンのストレージクラス"
  type        = string
  default     = "STANDARD_IA"
  
  validation {
    condition     = contains(["STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE"], var.noncurrent_version_storage_class)
    error_message = "非現行バージョンのストレージクラスは STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER, DEEP_ARCHIVE のいずれかである必要があります。"
  }
}

variable "noncurrent_version_expiration_days" {
  description = "非現行バージョンの削除日数"
  type        = number
  default     = 90
  
  validation {
    condition     = var.noncurrent_version_expiration_days >= 0
    error_message = "非現行バージョンの削除日数は0以上である必要があります。"
  }
}

variable "abort_incomplete_multipart_days" {
  description = "不完全なマルチパートアップロードの削除日数"
  type        = number
  default     = 7
  
  validation {
    condition     = var.abort_incomplete_multipart_days >= 0
    error_message = "不完全なマルチパートアップロードの削除日数は0以上である必要があります。"
  }
}

variable "enable_object_expiration" {
  description = "オブジェクトの自動削除の有効化"
  type        = bool
  default     = false
}

variable "object_expiration_days" {
  description = "オブジェクトの削除日数"
  type        = number
  default     = 365
  
  validation {
    condition     = var.object_expiration_days >= 0
    error_message = "オブジェクトの削除日数は0以上である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Access Logging
# -----------------------------------------------------------------------------

variable "enable_access_logging" {
  description = "アクセスログの有効化"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Inventory
# -----------------------------------------------------------------------------

variable "enable_inventory" {
  description = "インベントリの有効化"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Intelligent Tiering
# -----------------------------------------------------------------------------

variable "enable_intelligent_tiering" {
  description = "インテリジェントティアリングの有効化"
  type        = bool
  default     = false
}

variable "archive_access_days" {
  description = "アーカイブアクセスまでの日数"
  type        = number
  default     = 90
  
  validation {
    condition     = var.archive_access_days >= 0
    error_message = "アーカイブアクセスまでの日数は0以上である必要があります。"
  }
}

variable "deep_archive_access_days" {
  description = "ディープアーカイブアクセスまでの日数"
  type        = number
  default     = 180
  
  validation {
    condition     = var.deep_archive_access_days >= 0
    error_message = "ディープアーカイブアクセスまでの日数は0以上である必要があります。"
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for key, value in var.tags : 
      length(key) > 0 && length(key) <= 128 &&
      length(value) <= 256
    ])
    error_message = "タグのキーは1-128文字、値は256文字以内である必要があります。"
  }
}