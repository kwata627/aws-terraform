# ----- EC2インスタンスの作成（WordPress用） -----

# --- EC2インスタンスの作成（本番用） ---
resource "aws_instance" "wordpress" {
  ami           = var.ami_id                    # Amazon Linux 2023のAMI ID
  instance_type = var.instance_type             # インスタンスタイプ（例: t2.micro）
  key_name      = var.key_name                 # AWSキーペアを使用

  # ネットワーク設定
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true            # パブリックIPを割当

  # ストレージ設定
  root_block_device {
    volume_size = var.root_volume_size          # ルートボリュームサイズ（GB）
    volume_type = "gp2"                        # 汎用SSD
    encrypted   = true                         # 暗号化
  }

  # タグ設定
  tags = {
    Name = var.ec2_name
  }

  # UserDataで最小限の初期設定のみ（デバッグログ付き）
  user_data = base64encode(<<-EOF
              #!/bin/bash
              
              # デバッグログの開始
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "=== UserData開始: $(date) ==="
              
              # システムアップデート
              echo "システムアップデート開始..."
              yum update -y
              echo "システムアップデート完了"
              
              # SSHサービスの有効化
              echo "SSHサービス設定開始..."
              systemctl enable sshd
              systemctl start sshd
              echo "SSHサービス状態: $(systemctl is-active sshd)"
              
              # SSH設定ファイルの確認
              echo "SSH設定ファイル確認..."
              if [ -f /etc/ssh/sshd_config ]; then
                echo "SSH設定ファイル存在: /etc/ssh/sshd_config"
                grep -E "^(PubkeyAuthentication|AuthorizedKeysFile|PasswordAuthentication)" /etc/ssh/sshd_config || echo "設定項目が見つかりません"
              else
                echo "SSH設定ファイルが存在しません"
              fi
              
              # 基本的なSSH設定（Ansibleで詳細設定）
              echo "SSH公開鍵設定開始..."
              mkdir -p /home/ec2-user/.ssh
              echo "SSHディレクトリ作成完了: /home/ec2-user/.ssh"
              
              echo "${var.ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
              echo "SSH公開鍵設定完了"
              
              chmod 700 /home/ec2-user/.ssh
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              chown -R ec2-user:ec2-user /home/ec2-user/.ssh
              echo "SSH権限設定完了"
              
              # SSH設定の確認
              echo "SSH設定確認..."
              ls -la /home/ec2-user/.ssh/
              echo "authorized_keys内容確認:"
              cat /home/ec2-user/.ssh/authorized_keys
              
              # SSHサービス再起動
              echo "SSHサービス再起動..."
              systemctl restart sshd
              echo "SSHサービス再起動完了"
              
              # SSH設定テスト
              echo "SSH設定テスト..."
              /usr/sbin/sshd -t && echo "SSH設定テスト成功" || echo "SSH設定テスト失敗"
              
              echo "=== UserData完了: $(date) ==="
              EOF
  )

  # インスタンスが完全に起動するまで待機
  depends_on = []
}

# --- Elastic IPの確保（本番用） ---
resource "aws_eip" "wordpress" {
  instance = aws_instance.wordpress.id
  domain   = "vpc"

  tags = {
    Name = "${var.project}-wordpress-eip"
  }
}

# ----- 検証用EC2インスタンスの作成 -----

# --- 検証用EC2インスタンス ---
resource "aws_instance" "validation" {
  count = var.enable_validation_ec2 ? 1 : 0

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name  # 統一されたキーペアを使用

  # ネットワーク設定（プライベートサブネットに配置）
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.validation_security_group_id]  # 専用SGを使用
  associate_public_ip_address = false           # プライベートサブネットなのでfalse

  # ストレージ設定
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp2"
    encrypted   = true
  }

  # デフォルトで停止状態
  instance_initiated_shutdown_behavior = "stop"

  # タグ設定
  tags = {
    Name = var.validation_ec2_name
  }

  # UserDataで最小限の初期設定のみ（デバッグログ付き）
  user_data = base64encode(<<-EOF
              #!/bin/bash
              
              # デバッグログの開始
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "=== 検証用EC2 UserData開始: $(date) ==="
              
              # システムアップデート
              echo "システムアップデート開始..."
              yum update -y
              echo "システムアップデート完了"
              
              # SSHサービスの有効化
              echo "SSH設定開始..."
              systemctl enable sshd
              systemctl start sshd
              echo "SSHサービス状態: $(systemctl is-active sshd)"
              
              # SSH設定ファイルの確認
              echo "SSH設定ファイル確認..."
              if [ -f /etc/ssh/sshd_config ]; then
                echo "SSH設定ファイル存在: /etc/ssh/sshd_config"
                grep -E "^(PubkeyAuthentication|AuthorizedKeysFile|PasswordAuthentication)" /etc/ssh/sshd_config || echo "設定項目が見つかりません"
              else
                echo "SSH設定ファイルが存在しません"
              fi
              
              # 基本的なSSH設定（Ansibleで詳細設定）
              echo "SSH公開鍵設定開始..."
              mkdir -p /home/ec2-user/.ssh
              echo "SSHディレクトリ作成完了: /home/ec2-user/.ssh"
              
              echo "${var.ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
              echo "SSH公開鍵設定完了"
              
              chmod 700 /home/ec2-user/.ssh
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              chown -R ec2-user:ec2-user /home/ec2-user/.ssh
              echo "SSH権限設定完了"
              
              # SSH設定の確認
              echo "SSH設定確認..."
              ls -la /home/ec2-user/.ssh/
              echo "authorized_keys内容確認:"
              cat /home/ec2-user/.ssh/authorized_keys
              
              # SSHサービス再起動
              echo "SSHサービス再起動..."
              systemctl restart sshd
              echo "SSHサービス再起動完了"
              
              # SSH設定テスト
              echo "SSH設定テスト..."
              /usr/sbin/sshd -t && echo "SSH設定テスト成功" || echo "SSH設定テスト失敗"
              
              echo "=== 検証用EC2 UserData完了: $(date) ==="
              EOF
  )

  depends_on = []
}