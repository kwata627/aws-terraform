#!/bin/bash
# SSH設定の初期化（Amazon Linux 2023対応）
systemctl enable sshd
systemctl start sshd

# SSH公開鍵の配置
mkdir -p /home/ec2-user/.ssh
echo "${ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# SSH設定の確認
echo "SSH authorized_keys content:"
cat /home/ec2-user/.ssh/authorized_keys
echo "SSH directory permissions:"
ls -la /home/ec2-user/.ssh/

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