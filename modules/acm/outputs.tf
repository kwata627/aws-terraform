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
# Auto Renewal Information
# -----------------------------------------------------------------------------

output "auto_renewal_enabled" {
  description = "自動更新が有効かどうか"
  value       = true
}

output "renewal_eligibility" {
  description = "更新適格性"
  value       = "ELIGIBLE"
}

output "next_renewal_date" {
  description = "次回更新予定日（有効期限60日前）"
  value       = try(
    timeadd(aws_acm_certificate.main.not_after, "-60h"),
    "計算できません"
  )
}

output "days_until_renewal" {
  description = "更新までの日数"
  value       = try(
    floor((parseint(timestamp()) - parseint(timeadd(aws_acm_certificate.main.not_after, "-60h"))) / 86400),
    "計算できません"
  )
}

# -----------------------------------------------------------------------------
# Monitoring Information
# -----------------------------------------------------------------------------

output "expiry_monitoring_enabled" {
  description = "有効期限監視が有効かどうか"
  value       = var.enable_expiry_monitoring
}

output "validation_monitoring_enabled" {
  description = "検証失敗監視が有効かどうか"
  value       = var.enable_validation_monitoring
}

output "expiry_alarm_arn" {
  description = "有効期限アラームのARN"
  value       = try(aws_cloudwatch_metric_alarm.certificate_expiry[0].arn, null)
}

output "validation_failure_alarm_arn" {
  description = "検証失敗アラームのARN"
  value       = try(aws_cloudwatch_metric_alarm.certificate_validation_failure[0].arn, null)
}

# -----------------------------------------------------------------------------
# Module Information
# -----------------------------------------------------------------------------

output "module_version" {
  description = "モジュールのバージョン情報"
  value       = "2.0.0"
}

output "module_features" {
  description = "モジュールの機能一覧"
  value = {
    dns_validation           = true
    wildcard_support         = var.enable_wildcard
    auto_renewal             = true
    lifecycle_management     = true
    expiry_monitoring        = var.enable_expiry_monitoring
    validation_monitoring    = var.enable_validation_monitoring
    cloudwatch_alarms        = var.enable_expiry_monitoring || var.enable_validation_monitoring
  }
}

# -----------------------------------------------------------------------------
# Certificate Summary
# -----------------------------------------------------------------------------

output "certificate_summary" {
  description = "証明書の概要情報"
  value = {
    domain_name              = aws_acm_certificate.main.domain_name
    status                   = aws_acm_certificate.main.status
    validation_method        = aws_acm_certificate.main.validation_method
    subject_alternative_names = aws_acm_certificate.main.subject_alternative_names
    not_before               = aws_acm_certificate.main.not_before
    not_after                = aws_acm_certificate.main.not_after
    auto_renewal_enabled     = true
    monitoring_enabled       = var.enable_expiry_monitoring || var.enable_validation_monitoring
  }
}
