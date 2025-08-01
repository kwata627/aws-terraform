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

  # UserDataでWordPress自動インストール
  user_data = base64encode(<<-EOF
              #!/bin/bash
              
              # SSH設定の初期化（Amazon Linux 2023対応）
              systemctl enable sshd
              systemctl start sshd
              
              # SSH公開鍵の配置
              mkdir -p /home/ec2-user/.ssh
              echo "${var.ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
              chmod 700 /home/ec2-user/.ssh
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              chown -R ec2-user:ec2-user /home/ec2-user/.ssh
              
              yum update -y
              yum install -y httpd php php-mysqlnd php-gd php-mbstring php-xml php-curl mysql
              
              # Apache起動・自動起動設定
              systemctl start httpd
              systemctl enable httpd
              
              # WordPressダウンロード・設定
              cd /var/www/html
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              cp -r wordpress/* .
              rm -rf wordpress latest.tar.gz
              
              # 権限設定
              chown -R apache:apache /var/www/html
              chmod -R 755 /var/www/html
              
              # wp-config.phpの設定（後で手動でDB接続情報を設定）
              cp wp-config-sample.php wp-config.php
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
  # key_name      = var.key_name  # AWSキーペアを無効化

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

  # UserDataでWordPress自動インストール（本番と同じ）
  user_data = <<-EOF
              #!/bin/bash
              # SSH設定の初期化（Amazon Linux 2023対応）
              systemctl enable sshd
              systemctl start sshd
              
              # または、より確実な方法
              /usr/sbin/sshd -t
              systemctl status sshd
              
              # SSH公開鍵の配置
              mkdir -p /home/ec2-user/.ssh
              echo "${var.ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
              chmod 700 /home/ec2-user/.ssh
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              chown -R ec2-user:ec2-user /home/ec2-user/.ssh
              
              yum update -y
              yum install -y httpd php php-mysqlnd php-gd php-mbstring php-xml php-curl mysql
              
              # Apache起動・自動起動設定
              systemctl start httpd
              systemctl enable httpd
              
              # WordPressダウンロード・設定
              cd /var/www/html
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              cp -r wordpress/* .
              rm -rf wordpress latest.tar.gz
              
              # 権限設定
              chown -R apache:apache /var/www/html
              chmod -R 755 /var/www/html
              
              # wp-config.phpの設定（後で手動でDB接続情報を設定）
              cp wp-config-sample.php wp-config.php
              EOF

  depends_on = []
}