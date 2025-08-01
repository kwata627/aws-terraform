output "key_name" {
  description = "統一されたSSHキーペア名"
  value       = aws_key_pair.unified.key_name
}

output "key_id" {
  description = "統一されたSSHキーペアID"
  value       = aws_key_pair.unified.id
} 