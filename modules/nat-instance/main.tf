# --- NATインスタンスの作成 ---
resource "aws_instance" "nat" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name      = var.key_name  # AWSキーペアを有効化

  associate_public_ip_address = true
  source_dest_check = false # NATインスタンス必須

  user_data = <<-EOF
    #!/bin/bash
    
    # デバッグログの開始
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    echo "=== NAT UserData開始: $(date) ==="
    
    # SSH設定の初期化（Amazon Linux 2023対応）
    echo "SSH設定開始..."
    systemctl enable sshd
    systemctl start sshd
    echo "SSHサービス状態: $(systemctl is-active sshd)"
    
    # SSH設定ファイルの詳細確認と修正
    echo "SSH設定ファイル確認..."
    if [ -f /etc/ssh/sshd_config ]; then
      echo "SSH config file exists"
      # 公開鍵認証を有効化
      sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
      echo "SSH設定ファイル修正完了"
      # SSHサービスを再起動
      systemctl restart sshd
      systemctl status sshd
    else
      echo "SSH config file not found"
    fi
    
    # SSH公開鍵の配置
    echo "SSH公開鍵設定開始..."
    mkdir -p /home/ec2-user/.ssh
    echo "${var.ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    echo "SSH公開鍵設定完了"
    
    # SSH秘密鍵の配置（検証用インスタンス接続用）
    echo "SSH秘密鍵設定開始..."
    cat > /home/ec2-user/.ssh/id_rsa << 'INNER_EOF'
${var.ssh_private_key}
INNER_EOF
    chmod 600 /home/ec2-user/.ssh/id_rsa
    chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
    echo "SSH秘密鍵設定完了"
    
    # SSH設定の確認
    echo "SSH設定確認..."
    ls -la /home/ec2-user/.ssh/
    echo "authorized_keys内容確認:"
    cat /home/ec2-user/.ssh/authorized_keys
    
    # SSH設定テスト
    echo "SSH設定テスト..."
    /usr/sbin/sshd -t && echo "SSH設定テスト成功" || echo "SSH設定テスト失敗"
    
    # NAT設定
    echo "NAT設定開始..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -s 10.0.0.0/16 -j MASQUERADE
    echo "NAT設定完了"
    
    echo "=== NAT UserData完了: $(date) ==="
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