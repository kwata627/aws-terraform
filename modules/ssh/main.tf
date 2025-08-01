# ----- SSHキーペアの統一管理 -----

# --- 統一されたSSHキーペアの作成 ---
resource "aws_key_pair" "unified" {
  key_name   = "${var.project}-unified-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project}-unified-key"
  }
} 