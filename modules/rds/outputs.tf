output "db_endpoint" {
  description = "RDSエンドポイント（アプリケーションからの接続先）"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "作成したデータベース名"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "DBマスターユーザー名"
  value       = aws_db_instance.main.username
}

output "validation_db_endpoint" {
  description = "検証用RDSエンドポイント"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].endpoint : null
}

output "validation_db_name" {
  description = "検証用RDSのデータベース名"
  value       = var.enable_validation_rds ? aws_db_instance.validation[0].db_name : null
}