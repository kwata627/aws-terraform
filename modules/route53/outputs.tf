# =============================================================================
# Route53 Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Hosted Zone Outputs
# -----------------------------------------------------------------------------

output "zone_id" {
  description = "Route53ホストゾーンのID"
  value       = try(data.aws_route53_zone.existing[0].zone_id, try(aws_route53_zone.main[0].zone_id, null))
}

output "zone_name" {
  description = "Route53ホストゾーンの名前"
  value       = var.domain_name
}

output "zone_arn" {
  description = "Route53ホストゾーンのARN"
  value       = var.should_use_existing_zone && var.domain_exists_in_route53 && length(data.aws_route53_zone.existing) > 0 ? data.aws_route53_zone.existing[0].arn : (length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].arn : null)
}

output "name_servers" {
  description = "Route53ホストゾーンのネームサーバー"
  value       = try(data.aws_route53_zone.existing[0].name_servers, try(aws_route53_zone.main[0].name_servers, []))
}

output "zone_private" {
  description = "プライベートホストゾーンの有効化状態"
  value       = var.is_private_zone
}

output "zone_name_servers_count" {
  description = "ネームサーバーの数"
  value       = length(local.name_servers) > 0 ? length(local.name_servers) : 0
}

# -----------------------------------------------------------------------------
# Domain Registration Outputs
# -----------------------------------------------------------------------------

output "domain_registration_status" {
  description = "ドメイン登録の状態"
  value       = var.register_domain ? "Registered" : "Not registered"
}

output "domain_expiration_date" {
  description = "ドメインの有効期限"
  value       = var.register_domain ? "N/A" : "N/A"
}

output "domain_auto_renew" {
  description = "ドメインの自動更新状態"
  value       = var.register_domain ? true : false
}

output "registered_domain_name" {
  description = "登録されたドメイン名"
  value       = var.register_domain && length(aws_route53domains_registered_domain.main) > 0 ? aws_route53domains_registered_domain.main[0].domain_name : null
}

# -----------------------------------------------------------------------------
# DNS Records Outputs
# -----------------------------------------------------------------------------

output "dns_records_created" {
  description = "作成されたDNSレコードの数"
  value       = length(var.dns_records) + (var.wordpress_ip != "" ? 1 : 0) + (var.cloudfront_domain_name != "" ? 1 : 0)
}

output "wordpress_record_name" {
  description = "WordPress用Aレコードの名前"
  value       = var.wordpress_ip != "" ? var.domain_name : null
}

output "wordpress_record_created" {
  description = "WordPress用Aレコードが作成されたかどうか"
  value       = var.wordpress_ip != ""
}

output "cloudfront_record_name" {
  description = "CloudFront用CNAMEレコードの名前"
  value       = var.cloudfront_domain_name != "" ? "static.${var.domain_name}" : null
}

output "cloudfront_record_created" {
  description = "CloudFront用CNAMEレコードが作成されたかどうか"
  value       = var.cloudfront_domain_name != ""
}

output "additional_records_created" {
  description = "作成された追加DNSレコードの数"
  value       = length(var.dns_records)
}



# -----------------------------------------------------------------------------
# Health Check Outputs
# -----------------------------------------------------------------------------

output "health_checks_created" {
  description = "作成されたヘルスチェックの数"
  value       = var.enable_health_checks ? length(var.health_checks) : 0
}

output "health_check_ids" {
  description = "作成されたヘルスチェックのID一覧"
  value       = var.enable_health_checks ? values(aws_route53_health_check.main)[*].id : []
}

output "health_check_names" {
  description = "作成されたヘルスチェックの名前一覧"
  value       = var.enable_health_checks ? values(aws_route53_health_check.main)[*].fqdn : []
}

output "health_checks_enabled" {
  description = "ヘルスチェックが有効化されているかどうか"
  value       = var.enable_health_checks
}

# -----------------------------------------------------------------------------
# DNS Query Logging Outputs
# -----------------------------------------------------------------------------

output "query_logging_enabled" {
  description = "DNSクエリログの有効化状態"
  value       = var.enable_query_logging
}

output "query_log_group_arn" {
  description = "DNSクエリログ用CloudWatch Log GroupのARN"
  value       = var.enable_query_logging && length(aws_cloudwatch_log_group.route53_query_logs) > 0 ? aws_cloudwatch_log_group.route53_query_logs[0].arn : null
}

output "query_log_group_name" {
  description = "DNSクエリログ用CloudWatch Log Groupの名前"
  value       = var.enable_query_logging && length(aws_cloudwatch_log_group.route53_query_logs) > 0 ? aws_cloudwatch_log_group.route53_query_logs[0].name : null
}

output "query_logging_role_arn" {
  description = "DNSクエリログ用IAMロールのARN"
  value       = var.enable_query_logging && length(aws_iam_role.route53_query_logging) > 0 ? aws_iam_role.route53_query_logging[0].arn : null
}

output "query_log_retention_days" {
  description = "DNSクエリログの保持期間（日数）"
  value       = var.enable_query_logging && length(aws_cloudwatch_log_group.route53_query_logs) > 0 ? aws_cloudwatch_log_group.route53_query_logs[0].retention_in_days : null
}

# -----------------------------------------------------------------------------
# DNSSEC Outputs
# -----------------------------------------------------------------------------

output "dnssec_enabled" {
  description = "DNSSECの有効化状態"
  value       = var.enable_dnssec
}

output "dnssec_key_signing_key" {
  description = "DNSSEC鍵署名鍵の情報"
  value       = var.enable_dnssec && length(aws_route53_key_signing_key.main) > 0 ? aws_route53_key_signing_key.main[0].id : null
}

output "dnssec_key_signing_key_arn" {
  description = "DNSSEC鍵署名鍵のARN"
  value       = var.enable_dnssec && length(aws_route53_key_signing_key.main) > 0 ? aws_route53_key_signing_key.main[0].key_management_service_arn : null
}

output "dnssec_signing_algorithm" {
  description = "DNSSEC署名アルゴリズム"
  value       = var.enable_dnssec ? var.dnssec_signing_algorithm : null
}

# -----------------------------------------------------------------------------
# Private Zone Outputs
# -----------------------------------------------------------------------------

output "private_zone_enabled" {
  description = "プライベートホストゾーンの有効化状態"
  value       = var.is_private_zone
}

output "private_zone_vpc_associations" {
  description = "プライベートホストゾーンに関連付けられたVPC一覧"
  value       = var.is_private_zone ? values(aws_route53_zone_association.private)[*].vpc_id : []
}

output "private_zone_vpc_count" {
  description = "プライベートホストゾーンに関連付けられたVPCの数"
  value       = var.is_private_zone ? length(var.private_zone_vpc_ids) : 0
}

# -----------------------------------------------------------------------------
# Summary Outputs
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "Route53モジュールの設定サマリー"
  value = {
    domain_name = var.domain_name
    zone_id = local.hosted_zone_id
    is_private = var.is_private_zone
    dnssec_enabled = var.enable_dnssec
    query_logging_enabled = var.enable_query_logging
    health_checks_enabled = var.enable_health_checks
    domain_registered = var.register_domain
    total_records = length(var.dns_records) + (var.wordpress_ip != "" ? 1 : 0) + (var.cloudfront_domain_name != "" ? 1 : 0)
    total_health_checks = var.enable_health_checks ? length(var.health_checks) : 0
    vpc_associations = var.is_private_zone ? length(var.private_zone_vpc_ids) : 0
  }
}

output "security_features" {
  description = "有効化されているセキュリティ機能"
  value = {
    dnssec = var.enable_dnssec
    query_logging = var.enable_query_logging
    health_checks = var.enable_health_checks
    private_zone = var.is_private_zone
  }
}
