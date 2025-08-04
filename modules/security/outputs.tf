# =============================================================================
# Security Module Outputs (Refactored)
# =============================================================================
# 
# このファイルはSecurityモジュールの出力定義を含みます。
# 構造化されたセキュリティルール定義とセキュリティ監査機能に対応しています。
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group IDs
# -----------------------------------------------------------------------------

output "ec2_public_sg_id" {
  description = "EC2用セキュリティグループのID"
  value       = aws_security_group.ec2_public.id
}

output "ec2_private_sg_id" {
  description = "検証用EC2専用セキュリティグループID"
  value       = aws_security_group.ec2_private.id
}

output "rds_sg_id" {
  description = "RDS用セキュリティグループのID"
  value       = aws_security_group.rds.id
}

output "nat_instance_sg_id" {
  description = "NATインスタンス用セキュリティグループID"
  value       = aws_security_group.nat_instance.id
}

output "alb_sg_id" {
  description = "ALB用セキュリティグループのID"
  value       = var.enable_alb_security_group ? aws_security_group.alb[0].id : null
}

output "cache_sg_id" {
  description = "キャッシュ用セキュリティグループのID"
  value       = var.enable_cache_security_group ? aws_security_group.cache[0].id : null
}

# -----------------------------------------------------------------------------
# Security Group ARNs
# -----------------------------------------------------------------------------

output "ec2_public_sg_arn" {
  description = "EC2用セキュリティグループのARN"
  value       = aws_security_group.ec2_public.arn
}

output "ec2_private_sg_arn" {
  description = "検証用EC2専用セキュリティグループのARN"
  value       = aws_security_group.ec2_private.arn
}

output "rds_sg_arn" {
  description = "RDS用セキュリティグループのARN"
  value       = aws_security_group.rds.arn
}

output "nat_instance_sg_arn" {
  description = "NATインスタンス用セキュリティグループのARN"
  value       = aws_security_group.nat_instance.arn
}

output "alb_sg_arn" {
  description = "ALB用セキュリティグループのARN"
  value       = var.enable_alb_security_group ? aws_security_group.alb[0].arn : null
}

output "cache_sg_arn" {
  description = "キャッシュ用セキュリティグループのARN"
  value       = var.enable_cache_security_group ? aws_security_group.cache[0].arn : null
}

# -----------------------------------------------------------------------------
# Security Group Names
# -----------------------------------------------------------------------------

output "ec2_public_sg_name" {
  description = "EC2用セキュリティグループの名前"
  value       = aws_security_group.ec2_public.name
}

output "ec2_private_sg_name" {
  description = "検証用EC2専用セキュリティグループの名前"
  value       = aws_security_group.ec2_private.name
}

output "rds_sg_name" {
  description = "RDS用セキュリティグループの名前"
  value       = aws_security_group.rds.name
}

output "nat_instance_sg_name" {
  description = "NATインスタンス用セキュリティグループの名前"
  value       = aws_security_group.nat_instance.name
}

output "alb_sg_name" {
  description = "ALB用セキュリティグループの名前"
  value       = var.enable_alb_security_group ? aws_security_group.alb[0].name : null
}

output "cache_sg_name" {
  description = "キャッシュ用セキュリティグループの名前"
  value       = var.enable_cache_security_group ? aws_security_group.cache[0].name : null
}

# -----------------------------------------------------------------------------
# Security Audit Resources
# -----------------------------------------------------------------------------

output "security_audit_log_group_name" {
  description = "セキュリティ監査ロググループ名"
  value       = var.enable_security_audit ? aws_cloudwatch_log_group.security_audit[0].name : null
}

output "security_audit_role_arn" {
  description = "セキュリティ監査用IAMロールのARN"
  value       = var.enable_security_audit ? aws_iam_role.security_audit[0].arn : null
}

output "security_audit_role_name" {
  description = "セキュリティ監査用IAMロールの名前"
  value       = var.enable_security_audit ? aws_iam_role.security_audit[0].name : null
}

# -----------------------------------------------------------------------------
# Security Configuration Summary
# -----------------------------------------------------------------------------

output "security_groups_created" {
  description = "作成されたセキュリティグループの数"
  value = {
    ec2_public = 1
    ec2_private = 1
    rds = 1
    nat_instance = 1
    alb = var.enable_alb_security_group ? 1 : 0
    cache = var.enable_cache_security_group ? 1 : 0
    total = 4 + (var.enable_alb_security_group ? 1 : 0) + (var.enable_cache_security_group ? 1 : 0)
  }
}

output "security_groups_enabled" {
  description = "有効化されているセキュリティグループ"
  value = {
    ec2_public = true
    ec2_private = true
    rds = true
    nat_instance = true
    alb = var.enable_alb_security_group
    cache = var.enable_cache_security_group
  }
}

# -----------------------------------------------------------------------------
# Security Rules Configuration
# -----------------------------------------------------------------------------

output "security_rules_enabled" {
  description = "有効化されているセキュリティルール"
  value = {
    ssh = var.security_rules.ssh.enabled
    http = var.security_rules.http.enabled
    https = var.security_rules.https.enabled
    icmp = var.security_rules.icmp.enabled
    private_ssh = var.security_rules.private_ssh.enabled
    private_http = var.security_rules.private_http.enabled
    private_https = var.security_rules.private_https.enabled
    mysql = var.security_rules.mysql.enabled
    postgresql = var.security_rules.postgresql.enabled
    nat_ssh = var.security_rules.nat_ssh.enabled
    nat_icmp = var.security_rules.nat_icmp.enabled
    alb_http = var.security_rules.alb_http.enabled
    alb_https = var.security_rules.alb_https.enabled
    redis = var.security_rules.redis.enabled
    memcached = var.security_rules.memcached.enabled
  }
}

output "security_rules_cidr_blocks" {
  description = "設定されているCIDRブロック"
  value = {
    ssh = var.security_rules.ssh.allowed_cidrs
    http = var.security_rules.http.allowed_cidrs
    https = var.security_rules.https.allowed_cidrs
    icmp = var.security_rules.icmp.allowed_cidrs
    private_ssh = var.security_rules.private_ssh.allowed_cidrs
    private_http = var.security_rules.private_http.allowed_cidrs
    private_https = var.security_rules.private_https.allowed_cidrs
    mysql = var.security_rules.mysql.allowed_cidrs
    postgresql = var.security_rules.postgresql.allowed_cidrs
    nat_ssh = var.security_rules.nat_ssh.allowed_cidrs
    nat_icmp = var.security_rules.nat_icmp.allowed_cidrs
    alb_http = var.security_rules.alb_http.allowed_cidrs
    alb_https = var.security_rules.alb_https.allowed_cidrs
    redis = var.security_rules.redis.allowed_cidrs
    memcached = var.security_rules.memcached.allowed_cidrs
    egress = var.security_rules.egress.allowed_cidrs
  }
}

# -----------------------------------------------------------------------------
# Security Features Status
# -----------------------------------------------------------------------------

output "security_features_enabled" {
  description = "有効化されているセキュリティ機能"
  value = {
    security_audit = var.enable_security_audit
    security_compliance = var.enable_security_compliance
    security_monitoring = var.enable_security_monitoring
    security_automation = var.enable_security_automation
    alb_security_group = var.enable_alb_security_group
    cache_security_group = var.enable_cache_security_group
    custom_rules = length(var.custom_security_rules) > 0
  }
}

output "security_compliance_standards" {
  description = "適用されているコンプライアンス標準"
  value = var.compliance_standards
}

output "security_automation_actions" {
  description = "設定されているセキュリティ自動化アクション"
  value = var.security_automation_actions
}

# -----------------------------------------------------------------------------
# Security Monitoring Configuration
# -----------------------------------------------------------------------------

output "security_monitoring_config" {
  description = "セキュリティ監視設定"
  value = {
    enabled = var.enable_security_monitoring
    interval_minutes = var.security_monitoring_interval
    audit_enabled = var.enable_security_audit
    audit_retention_days = var.security_audit_retention_days
    notification_email = var.security_notification_email
  }
}

# -----------------------------------------------------------------------------
# Module Summary
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "Securityモジュールの設定サマリー"
  value = {
    project = var.project
    environment = var.environment
    vpc_id = var.vpc_id
    total_security_groups = 4 + (var.enable_alb_security_group ? 1 : 0) + (var.enable_cache_security_group ? 1 : 0)
    enabled_rules_count = length([
      for rule in [
        var.security_rules.ssh.enabled,
        var.security_rules.http.enabled,
        var.security_rules.https.enabled,
        var.security_rules.icmp.enabled,
        var.security_rules.private_ssh.enabled,
        var.security_rules.private_http.enabled,
        var.security_rules.private_https.enabled,
        var.security_rules.mysql.enabled,
        var.security_rules.postgresql.enabled,
        var.security_rules.nat_ssh.enabled,
        var.security_rules.nat_icmp.enabled,
        var.security_rules.alb_http.enabled,
        var.security_rules.alb_https.enabled,
        var.security_rules.redis.enabled,
        var.security_rules.memcached.enabled
      ] : rule if rule
    ])
    custom_rules_count = length(var.custom_security_rules)
    security_audit_enabled = var.enable_security_audit
    security_monitoring_enabled = var.enable_security_monitoring
    security_automation_enabled = var.enable_security_automation
    compliance_standards_count = length(var.compliance_standards)
  }
}

output "security_risk_assessment" {
  description = "セキュリティリスク評価"
  value = {
    high_risk_indicators = {
      public_ssh_access = var.security_rules.ssh.enabled && contains(var.security_rules.ssh.allowed_cidrs, "0.0.0.0/0")
      public_http_access = var.security_rules.http.enabled && contains(var.security_rules.http.allowed_cidrs, "0.0.0.0/0")
      public_https_access = var.security_rules.https.enabled && contains(var.security_rules.https.allowed_cidrs, "0.0.0.0/0")
      nat_public_access = var.security_rules.nat_ssh.enabled && contains(var.security_rules.nat_ssh.allowed_cidrs, "0.0.0.0/0")
      rds_public_access = var.security_rules.mysql.enabled && length(var.security_rules.mysql.allowed_cidrs) > 0
    }
    security_controls = {
      security_audit_enabled = var.enable_security_audit
      security_monitoring_enabled = var.enable_security_monitoring
      security_automation_enabled = var.enable_security_automation
      compliance_standards_applied = length(var.compliance_standards) > 0
    }
    recommendations = [
      var.security_rules.ssh.enabled && contains(var.security_rules.ssh.allowed_cidrs, "0.0.0.0/0") ? "SSHアクセスを特定のIPアドレスに制限することを推奨します" : null,
      var.security_rules.http.enabled && contains(var.security_rules.http.allowed_cidrs, "0.0.0.0/0") ? "HTTPアクセスをHTTPSにリダイレクトすることを推奨します" : null,
      !var.enable_security_audit ? "セキュリティ監査機能の有効化を推奨します" : null,
      !var.enable_security_monitoring ? "セキュリティ監視機能の有効化を推奨します" : null,
      length(var.compliance_standards) == 0 ? "コンプライアンス標準の適用を検討してください" : null
    ]
  }
}