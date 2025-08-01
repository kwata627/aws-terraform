# --- NATインスタンスの作成 ---
resource "aws_instance" "nat" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  # key_name      = var.key_name  # AWSキーペアを無効化

  associate_public_ip_address = true
  source_dest_check = false # NATインスタンス必須

  user_data = <<-EOF
    #!/bin/bash
    # SSH設定の初期化（Amazon Linux 2023対応）
    systemctl enable sshd
    systemctl start sshd
    
    # SSH設定ファイルの詳細確認と修正
    if [ -f /etc/ssh/sshd_config ]; then
      echo "SSH config file exists"
      # 公開鍵認証を有効化
      sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
      # SSHサービスを再起動
      systemctl restart sshd
      systemctl status sshd
    else
      echo "SSH config file not found"
    fi
    
    # SSH公開鍵の配置（直接記述）
    mkdir -p /home/ec2-user/.ssh
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBdeowGnmt4rIevee27PwvMXKhdn6bA1WqC3Tk0BAL6S kwata627@wata-pc" > /home/ec2-user/.ssh/authorized_keys
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    
    # NAT設定
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -s 10.0.0.0/16 -j MASQUERADE
  EOF

  tags = {
    Name = "${var.project}-nat-instance"
  }
}

# --- EIP割当 ---
resource "aws_eip" "nat" {
  instance = aws_instance.nat.id
  domain   = "vpc"
  tags = {
    Name = "${var.project}-nat-eip"
  }
} 