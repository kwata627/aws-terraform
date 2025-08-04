# =============================================================================
# RDS Module Outputs
# =============================================================================

output "db_endpoint" {
  description = "RDSエンドポイント（アプリケーションからの接続先）"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDSポート番号"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "作成したデータベース名"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "DBマスターユーザー名"
  value       = aws_db_instance.main.username
}

output "db_identifier" {
  description = "RDSインスタンス識別子"
  value       = aws_db_instance.main.id
}

output "db_arn" {
  description = "RDSインスタンスのARN"
  value       = aws_db_instance.main.arn
}

output "db_status" {
  description = "RDSインスタンスのステータス"
  value       = aws_db_instance.main.status
}

output "db_subnet_group_name" {
  description = "DBサブネットグループ名"
  value       = aws_db_subnet_group.main.name
}

output "db_parameter_group_name" {
  description = "DBパラメータグループ名"
  value       = aws_db_parameter_group.main.name
}

output "db_availability_zone" {
  description = "RDSインスタンスのアベイラビリティゾーン"
  value       = aws_db_instance.main.availability_zone
}

output "db_multi_az" {
  description = "マルチAZ配置の有効化状態"
  value       = aws_db_instance.main.multi_az
}

output "db_storage_encrypted" {
  description = "ストレージ暗号化の有効化状態"
  value       = aws_db_instance.main.storage_encrypted
}

output "db_backup_retention_period" {
  description = "バックアップ保持期間"
  value       = aws_db_instance.main.backup_retention_period
}

output "db_performance_insights_enabled" {
  description = "Performance Insightsの有効化状態"
  value       = aws_db_instance.main.performance_insights_enabled
}

# 検証用RDS出力
output "validation_db_endpoint" {
  description = "検証用RDSエンドポイント"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].endpoint : null
}

output "validation_db_port" {
  description = "検証用RDSポート番号"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].port : null
}

output "validation_db_name" {
  description = "検証用RDSのデータベース名"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].db_name : null
}

output "validation_db_identifier" {
  description = "検証用RDSインスタンス識別子"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].id : null
}

output "validation_db_arn" {
  description = "検証用RDSインスタンスのARN"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].arn : null
}

output "validation_db_status" {
  description = "検証用RDSインスタンスのステータス"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].status : null
}

# 監視・ログ出力
output "cloudwatch_logs_enabled" {
  description = "CloudWatchログの有効化状態"
  value       = var.enable_cloudwatch_logs
}

output "performance_insights_enabled" {
  description = "Performance Insightsの有効化状態"
  value       = var.enable_performance_insights
}

output "enhanced_monitoring_enabled" {
  description = "詳細モニタリングの有効化状態"
  value       = var.enable_enhanced_monitoring
}