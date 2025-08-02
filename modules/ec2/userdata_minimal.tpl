#!/bin/bash
# 最小限の初期設定（Ansible移行用）

# SSH設定の初期化
systemctl enable sshd
systemctl start sshd

# SSH公開鍵の配置
mkdir -p /home/ec2-user/.ssh
echo "${ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# 基本的なセキュリティ設定
yum update -y

# Ansible実行の準備（必要に応じて）
# yum install -y python3

# ログ出力
echo "Minimal UserData completed at $(date)" >> /var/log/user-data.log 