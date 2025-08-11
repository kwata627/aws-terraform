# =============================================================================
# ACM Certificate Module
# =============================================================================
# 
# このモジュールはAWS Certificate Manager (ACM) を使用してSSL/TLS証明書を
# 作成し、HTTPS通信を有効にします。CloudFrontとの統合を考慮して
# us-east-1リージョンでの証明書作成を想定しています。
#
# 特徴:
# - DNS検証方式による証明書発行
# - ワイルドカード証明書対応 (*.domain.com)
# - 自動更新対応
# - 適切なライフサイクル管理
# - 証明書の監視とアラート
# - DNS検証レコードの自動設定
# =============================================================================

# -----------------------------------------------------------------------------
# Required Providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# ACM Certificate Resource
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "main" {
  # CloudFrontとの統合のため、us-east-1リージョンでの作成が必要
  # プロバイダーは呼び出し元で指定
  provider = aws

  # プライマリドメイン名
  domain_name = var.domain_name

  # DNS検証方式（推奨）
  # - より安全で自動化しやすい
  # - メール検証と比較して確実性が高い
  validation_method = var.validation_method

  # サブジェクト代替名（SAN）の設定
  # ワイルドカード証明書により、サブドメインもカバー
  subject_alternative_names = local.final_san_list

  # 証明書のライフサイクル管理
  # create_before_destroy: 新しい証明書を作成してから古い証明書を削除
  # これにより、証明書の更新時にダウンタイムを最小化
  lifecycle {
    create_before_destroy = true
  }

  # リソースタグ
  # プロジェクト管理、コスト管理、セキュリティ監査に活用
  tags = merge(
    {
      Name        = "${var.project}-acm-certificate"
      Environment = var.environment
      Module      = "acm"
      ManagedBy   = "terraform"
      AutoRenew   = "true"
      RenewalDate = "60-days-before-expiry"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# DNS Validation Records
# -----------------------------------------------------------------------------

# DNS検証用のRoute53レコードを自動作成
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# -----------------------------------------------------------------------------
# Certificate Validation
# -----------------------------------------------------------------------------

# 証明書の検証完了を待機
resource "aws_acm_certificate_validation" "main" {
  provider                = aws
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# -----------------------------------------------------------------------------
# Certificate Monitoring and Alerts
# -----------------------------------------------------------------------------

# 証明書の有効期限を監視するCloudWatchアラーム
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.enable_expiry_monitoring ? 1 : 0

  alarm_name          = "${var.project}-certificate-expiry-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400" # 24時間
  statistic           = "Average"
  threshold           = "30"    # 30日前にアラート
  alarm_description   = "SSL証明書の有効期限が30日以内に迫っています"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CertificateArn = aws_acm_certificate.main.arn
  }

  tags = merge(
    {
      Name        = "${var.project}-certificate-expiry-alarm"
      Environment = var.environment
      Module      = "acm"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# 証明書の検証失敗を監視するCloudWatchアラーム
resource "aws_cloudwatch_metric_alarm" "certificate_validation_failure" {
  count = var.enable_validation_monitoring ? 1 : 0

  alarm_name          = "${var.project}-certificate-validation-failure-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ValidationFailed"
  namespace           = "AWS/CertificateManager"
  period              = "300"   # 5分
  statistic           = "Sum"
  threshold           = "0"     # 1回でも失敗したらアラート
  alarm_description   = "SSL証明書の検証が失敗しました"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CertificateArn = aws_acm_certificate.main.arn
  }

  tags = merge(
    {
      Name        = "${var.project}-certificate-validation-failure-alarm"
      Environment = var.environment
      Module      = "acm"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

