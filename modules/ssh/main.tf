# ----- SSHキーペアの統一管理 -----

# --- RSA鍵ペアの生成 ---
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- 統一されたSSHキーペアの作成 ---
resource "aws_key_pair" "unified" {
  key_name   = "${var.project}-unified-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${var.project}-unified-key"
  }
} 