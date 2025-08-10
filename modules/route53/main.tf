# =============================================================================
# Route53 Module - Main Configuration
# =============================================================================
# 
# このモジュールはAWS Route53ホストゾーンとDNSレコードを作成し、
# WordPress環境のDNS管理を提供します。セキュリティ強化と監視機能を
# 考慮した設計となっています。
#
# 特徴:
# - セキュリティ強化されたDNS設定
# - 柔軟なDNSレコード管理
# - ヘルスチェック機能
# - DNSクエリログ対応
# - DNSSEC対応
# - 詳細なタグ管理
# =============================================================================

# -----------------------------------------------------------------------------
# Required Providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # 共通タグ
  common_tags = merge(
    {
      Name        = "${var.project}-route53"
      Environment = var.environment
      Module      = "route53"
      ManagedBy   = "terraform"
      Project     = var.project
    },
    var.tags
  )
  
  # ホストゾーン名の正規化
  normalized_domain_name = lower(var.domain_name)
  
  # リソース名の生成
  resource_names = {
    hosted_zone     = "${var.project}-hosted-zone"
    query_log_group = var.query_log_group_name != "" ? var.query_log_group_name : "/aws/route53/${local.normalized_domain_name}"
    query_logging_role = "${var.project}-route53-query-logging-role"
    dnssec_ksk     = "${var.project}-dnssec-ksk"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for DNS Query Logging (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "route53_query_logs" {
  count = var.enable_query_logging ? 1 : 0

  name              = local.resource_names.query_log_group
  retention_in_days = var.query_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_names.hosted_zone}-query-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM Role for DNS Query Logging (Optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "route53_query_logging" {
  count = var.enable_query_logging ? 1 : 0

  name = local.resource_names.query_logging_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.resource_names.query_logging_role
    }
  )
}

resource "aws_iam_role_policy" "route53_query_logging" {
  count = var.enable_query_logging ? 1 : 0

  name = "${local.resource_names.query_logging_role}-policy"
  role = aws_iam_role.route53_query_logging[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.route53_query_logs[0].arn,
          "${aws_cloudwatch_log_group.route53_query_logs[0].arn}:*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Route53 Hosted Zone
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  name = local.normalized_domain_name

  # プライベートホストゾーン設定
  dynamic "vpc" {
    for_each = var.is_private_zone ? var.private_zone_vpc_ids : []
    content {
      vpc_id = vpc.value
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.resource_names.hosted_zone
    }
  )
}

# -----------------------------------------------------------------------------
# Domain Registration (Optional)
# -----------------------------------------------------------------------------

resource "aws_route53domains_registered_domain" "main" {
  count = var.register_domain ? 1 : 0

  provider = aws.us_east_1

  domain_name = local.normalized_domain_name

  # 登録者情報
  registrant_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 管理者情報（登録者と同じ）
  admin_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 技術担当者情報（登録者と同じ）
  tech_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 自動更新を有効化
  auto_renew = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-registered-domain"
    }
  )
}

# -----------------------------------------------------------------------------
# Health Checks (Optional)
# -----------------------------------------------------------------------------

resource "aws_route53_health_check" "main" {
  for_each = var.enable_health_checks ? { for idx, check in var.health_checks : check.name => check } : {}

  fqdn              = each.value.fqdn
  port              = each.value.port
  type              = each.value.type
  resource_path     = each.value.resource_path
  failure_threshold = each.value.failure_threshold
  request_interval  = each.value.request_interval

  # regionsブロックは削除（AWS Route53ヘルスチェックでは使用できない）

  tags = merge(
    local.common_tags,
    each.value.tags,
    {
      Name = each.value.name
    }
  )
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

# WordPress用Aレコード
resource "aws_route53_record" "wordpress" {
  zone_id = aws_route53_zone.main.zone_id
  name    = local.normalized_domain_name
  type    = "A"
  ttl     = "300"
  records = var.wordpress_ip != "" ? [var.wordpress_ip] : []

  # Route53レコードではタグは使用できないため削除
}

# CloudFront用CNAMEレコード
resource "aws_route53_record" "cloudfront" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "static.${local.normalized_domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = var.cloudfront_domain_name != "" ? [var.cloudfront_domain_name] : []

  # Route53レコードではタグは使用できないため削除
}

# ACM証明書検証用レコード
resource "aws_route53_record" "cert_validation" {
  for_each = var.certificate_validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id

  # Route53レコードではタグは使用できないため削除
}

# 追加のDNSレコード
resource "aws_route53_record" "additional" {
  for_each = { for idx, record in var.dns_records : idx => record }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  # エイリアスレコード設定
  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  # ヘルスチェック設定
  health_check_id = each.value.health_check_id

  # ルーティング設定（Route53レコードでは使用できない属性を削除）
  set_identifier = each.value.set_identifier

  # Route53レコードではタグは使用できないため削除
}

# -----------------------------------------------------------------------------
# DNSSEC (Optional)
# -----------------------------------------------------------------------------

resource "aws_route53_key_signing_key" "main" {
  count = var.enable_dnssec ? 1 : 0

  hosted_zone_id             = aws_route53_zone.main.id
  key_management_service_arn = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/alias/aws/route53"
  name                       = "key-signing-key"

  # DNSSECキー署名鍵ではタグは使用できないため削除
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  count = var.enable_dnssec ? 1 : 0

  hosted_zone_id = aws_route53_zone.main.id
}

# -----------------------------------------------------------------------------
# Private Zone Associations (Optional)
# -----------------------------------------------------------------------------

resource "aws_route53_zone_association" "private" {
  for_each = var.is_private_zone ? { for vpc_id in var.private_zone_vpc_ids : vpc_id => vpc_id } : {}

  zone_id = aws_route53_zone.main.zone_id
  vpc_id  = each.value
}