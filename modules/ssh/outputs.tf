output "key_name" {
  description = "統一されたSSHキーペア名"
  value       = aws_key_pair.unified.key_name
}

output "key_id" {
  description = "統一されたSSHキーペアID"
  value       = aws_key_pair.unified.id
}

output "private_key_pem" {
  description = "生成されたRSA秘密鍵（PEM形式）"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "生成されたRSA公開鍵（OpenSSH形式）"
  value       = tls_private_key.ssh.public_key_openssh
} 