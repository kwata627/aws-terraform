# =============================================================================
# ACM Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Certificate Information
# -----------------------------------------------------------------------------

output "certificate_arn" {
  description = "作成したACM証明書のARN"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain_name" {
  description = "証明書のプライマリドメイン名"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "証明書の現在のステータス"
  value       = aws_acm_certificate.main.status
}

output "certificate_validation_method" {
  description = "証明書の検証方式"
  value       = aws_acm_certificate.main.validation_method
}

# -----------------------------------------------------------------------------
# Validation Records
# -----------------------------------------------------------------------------

output "validation_records" {
  description = "DNS検証用のレコード情報（Route53での設定に使用）"
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}

output "validation_record_names" {
  description = "検証用DNSレコードの名前一覧"
  value       = [for dvo in aws_acm_certificate.main.domain_validation_options : dvo.resource_record_name]
}

output "validation_record_values" {
  description = "検証用DNSレコードの値一覧"
  value       = [for dvo in aws_acm_certificate.main.domain_validation_options : dvo.resource_record_value]
}

# -----------------------------------------------------------------------------
# Certificate Details
# -----------------------------------------------------------------------------

output "subject_alternative_names" {
  description = "証明書に含まれるサブジェクト代替名（SAN）のリスト"
  value       = aws_acm_certificate.main.subject_alternative_names
}

output "certificate_not_after" {
  description = "証明書の有効期限"
  value       = aws_acm_certificate.main.not_after
}

output "certificate_not_before" {
  description = "証明書の有効開始日"
  value       = aws_acm_certificate.main.not_before
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
    dns_validation     = true
    wildcard_support   = var.enable_wildcard
    auto_renewal       = true
    lifecycle_management = true
  }
}
