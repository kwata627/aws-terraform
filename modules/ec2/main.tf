# ----- EC2インスタンスの作成（WordPress用） -----

# --- キーペアの作成 ---
resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project}-key"
  }
}

# --- EC2インスタンスの作成 ---
resource "aws_instance" "wordpress" {
  ami           = var.ami_id                    # Amazon Linux 2023のAMI ID
  instance_type = var.instance_type             # インスタンスタイプ（例: t2.micro）
  key_name      = aws_key_pair.main.key_name   # SSHキーペア

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
  user_data = <<-EOF
              #!/bin/bash
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

  # インスタンスが完全に起動するまで待機
  depends_on = [aws_key_pair.main]
}

# --- Elastic IPの確保 ---
resource "aws_eip" "wordpress" {
  instance = aws_instance.wordpress.id
  domain   = "vpc"

  tags = {
    Name = "${var.project}-wordpress-eip"
  }
}