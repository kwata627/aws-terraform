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