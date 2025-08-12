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
# - 既存ホストゾーンの強制再作成機能
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

# ホストゾーン選択スクリプトの実行
data "external" "hosted_zone_selection" {
  count = var.should_use_existing_zone && var.domain_exists_in_route53 ? 1 : 0
  
  program = ["bash", "${path.module}/scripts/select_hosted_zone.sh", "-d", var.domain_name, "-t"]
  
  query = {
    DOMAIN_NAME = var.domain_name
  }
}

# 既存のRoute53ホストゾーンを検索（選択されたホストゾーンIDを使用）
data "aws_route53_zone" "existing" {
  count = var.should_use_existing_zone && var.domain_exists_in_route53 && length(data.external.hosted_zone_selection) > 0 && try(data.external.hosted_zone_selection[0].result.selected_zone_id, null) != null ? 1 : 0
  zone_id = try(data.external.hosted_zone_selection[0].result.selected_zone_id, null)
}

# ドメイン登録時のネームサーバー情報を取得
data "external" "domain_nameservers" {
  count = var.should_use_existing_zone && var.domain_exists_in_route53 && var.domain_registered ? 1 : 0
  
  program = ["bash", "${path.module}/scripts/get_domain_nameservers.sh", "-d", var.domain_name, "-t"]
  
  # 環境変数を設定
  query = {
    DOMAIN_NAME = var.domain_name
  }
}

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
  
  # ホストゾーンの決定（既存または新規）
  # 選択スクリプトの結果または既存のホストゾーンを使用、存在しない場合は新規作成
  hosted_zone_id = try(data.external.hosted_zone_selection[0].result.selected_zone_id, try(data.aws_route53_zone.existing[0].zone_id, try(aws_route53_zone.main[0].zone_id, "Z04134961ZPYYOPGD0LQY")))
  name_servers = try(data.aws_route53_zone.existing[0].name_servers, try(aws_route53_zone.main[0].name_servers, []))
  
  # 強制再作成フラグ（既存ホストゾーンが存在し、ネームサーバーが不一致の場合）
  force_recreate_zone = var.should_use_existing_zone && var.domain_exists_in_route53 && var.domain_registered && length(data.external.domain_nameservers) > 0 && try(data.external.domain_nameservers[0].result.error, "") == "" && length(data.aws_route53_zone.existing) > 0 ? (
    length(setintersection(
      try(data.aws_route53_zone.existing[0].name_servers, []),
      jsondecode(data.external.domain_nameservers[0].result.nameservers)
    )) < 4
  ) : false
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

# 新しいホストゾーンの作成（既存ホストゾーンが存在しない場合、または強制再作成の場合）
resource "aws_route53_zone" "main" {
  count = (!var.should_use_existing_zone || !var.domain_exists_in_route53 || local.force_recreate_zone) && (length(data.external.hosted_zone_selection) == 0 || try(data.external.hosted_zone_selection[0].result.should_create_new, "false") == "true" || local.force_recreate_zone) ? 1 : 0
  
  name = local.normalized_domain_name
  comment = "Hosted zone for ${var.domain_name} managed by Terraform"

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
  
  # 強制再作成の場合のライフサイクル設定
  lifecycle {
    create_before_destroy = true
  }
}

# 既存ホストゾーンの削除（強制再作成の場合）
resource "null_resource" "delete_existing_hosted_zone" {
  count = local.force_recreate_zone && length(data.aws_route53_zone.existing) > 0 ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "既存ホストゾーンを削除中: ${data.aws_route53_zone.existing[0].zone_id}"
      
      # すべてのレコードを削除
      aws route53 list-resource-record-sets --hosted-zone-id ${data.aws_route53_zone.existing[0].zone_id} --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`].{Name:Name,Type:Type,TTL:TTL,ResourceRecords:ResourceRecords}' --output json | \
      jq -r '.[] | "aws route53 change-resource-record-sets --hosted-zone-id ${data.aws_route53_zone.existing[0].zone_id} --change-batch '\''{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":{\"Name\":\"'$Name'\",\"Type\":\"'$Type'\",\"TTL\":'$TTL',\"ResourceRecords\":'$ResourceRecords'}}]}'\''"' | \
      while read cmd; do
        if [ -n "$cmd" ]; then
          echo "実行: $cmd"
          eval "$cmd"
        fi
      done
      
      # ホストゾーンを削除
      aws route53 delete-hosted-zone --id ${data.aws_route53_zone.existing[0].zone_id}
      
      echo "既存ホストゾーンの削除が完了しました"
    EOT
  }
  
  depends_on = [aws_route53_zone.main]
}

# -----------------------------------------------------------------------------
# Domain Registration Check and Registration
# -----------------------------------------------------------------------------

# ドメイン登録状況の確認と登録処理
data "external" "domain_check" {
  program = ["bash", "${path.module}/scripts/check_and_register_domain.sh", "-d", var.domain_name, "-f", "${path.root}/terraform.tfvars"]
  
  # スクリプトが失敗した場合の処理
  query = {
    domain_name = var.domain_name
  }
}

locals {
  # スクリプトの結果を解析
  domain_check_result = data.external.domain_check.result
  should_register_domain = try(local.domain_check_result.register_domain, "false") == "true"
  domain_unavailable = try(local.domain_check_result.domain_unavailable, "false") == "true"
}

# ドメイン登録リソース（条件付き）
resource "aws_route53domains_registered_domain" "main" {
  count = local.should_register_domain ? 1 : 0

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

  # プライバシー保護設定
  admin_privacy      = true
  registrant_privacy = true
  tech_privacy       = true

  # 自動更新を有効化
  auto_renew = true

  # 転送ロックを有効化
  transfer_lock = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-registered-domain"
    }
  )

  # ライフサイクル設定
  lifecycle {
    create_before_destroy = true
  }
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

# NSレコード（DelegationSetに基づく設定）
resource "aws_route53_record" "nameservers" {
  count = (var.should_use_existing_zone && var.domain_exists_in_route53 && var.domain_registered && length(data.external.domain_nameservers) > 0 && try(data.external.domain_nameservers[0].result.error, "") == "" && !local.force_recreate_zone) || length(aws_route53_zone.main) > 0 ? 1 : 0
  
  zone_id = local.hosted_zone_id
  name    = local.normalized_domain_name
  type    = "NS"
  ttl     = "60"
  
  # 既存のNSレコードを上書きする
  allow_overwrite = true
  
  # ネームサーバーの設定ロジック
  # 1. 新規ホストゾーンの場合：DelegationSet（自動割り当てされたネームサーバー）を使用
  # 2. 既存ホストゾーンで強制再作成の場合：新規ホストゾーンのネームサーバーを使用
  # 3. 既存ホストゾーンで強制再作成でない場合：ホストゾーンのネームサーバーを使用（ドメイン登録時のネームサーバーと一致させる）
  records = length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].name_servers : (
    local.force_recreate_zone ? [] : try(data.aws_route53_zone.existing[0].name_servers, [])
  )
}

# WordPress用Aレコード
resource "aws_route53_record" "wordpress" {
  zone_id = local.hosted_zone_id
  name    = local.normalized_domain_name
  type    = "A"
  ttl     = "300"
  records = var.wordpress_ip != "" ? [var.wordpress_ip] : []

  # Route53レコードではタグは使用できないため削除
}

# CloudFront用CNAMEレコード
resource "aws_route53_record" "cloudfront" {
  count = var.cloudfront_domain_name != "" ? 1 : 0
  
  zone_id = local.hosted_zone_id
  name    = "static.${local.normalized_domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [var.cloudfront_domain_name]

  # Route53レコードではタグは使用できないため削除
}

# 追加のDNSレコード
resource "aws_route53_record" "additional" {
  for_each = { for idx, record in var.dns_records : idx => record }

  zone_id = local.hosted_zone_id
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
  count = var.enable_dnssec && (!var.should_use_existing_zone || !var.domain_exists_in_route53 || local.force_recreate_zone) ? 1 : 0

  hosted_zone_id             = local.hosted_zone_id
  key_management_service_arn = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/alias/aws/route53"
  name                       = "key-signing-key"

  # DNSSECキー署名鍵ではタグは使用できないため削除
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  count = var.enable_dnssec && (!var.should_use_existing_zone || !var.domain_exists_in_route53 || local.force_recreate_zone) ? 1 : 0

  hosted_zone_id = local.hosted_zone_id
}

# -----------------------------------------------------------------------------
# Private Zone Associations (Optional)
# -----------------------------------------------------------------------------

resource "aws_route53_zone_association" "private" {
  for_each = var.is_private_zone ? { for vpc_id in var.private_zone_vpc_ids : vpc_id => vpc_id } : {}

  zone_id = local.hosted_zone_id
  vpc_id  = each.value
  vpc_region = data.aws_region.current.name

  # プライベートゾーン関連付けではタグは使用できないため削除
}