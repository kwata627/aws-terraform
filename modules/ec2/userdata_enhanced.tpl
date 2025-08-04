#!/bin/bash
# =============================================================================
# Enhanced UserData Template for EC2 Instance
# =============================================================================
# 
# このスクリプトはEC2インスタンスの初期設定を行います。
# セキュリティ強化、ログ管理、Ansible統合を考慮した設計です。
#
# パラメータ:
# - ssh_public_key: SSH公開鍵
# - project: プロジェクト名
# - environment: 環境名
# - additional_scripts: 追加スクリプト
# =============================================================================

# ログ設定
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Enhanced UserData開始: $(date) ==="
echo "プロジェクト: ${project}"
echo "環境: ${environment}"

# -----------------------------------------------------------------------------
# システムアップデート
# -----------------------------------------------------------------------------
echo "システムアップデート開始..."
yum update -y
echo "システムアップデート完了"

# -----------------------------------------------------------------------------
# SSH設定
# -----------------------------------------------------------------------------
echo "SSH設定開始..."

# SSHサービスの有効化
systemctl enable sshd
systemctl start sshd
echo "SSHサービス状態: $(systemctl is-active sshd)"

# SSH公開鍵設定
echo "SSH公開鍵設定開始..."
mkdir -p /home/ec2-user/.ssh
echo "${ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
echo "SSH設定完了"

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

# -----------------------------------------------------------------------------
# セキュリティ強化
# -----------------------------------------------------------------------------
echo "セキュリティ強化開始..."

# ファイアウォール設定（必要に応じて）
# systemctl enable firewalld
# systemctl start firewalld

# セキュリティアップデート
yum install -y yum-cron
sed -i 's/update_cmd = default/update_cmd = security/' /etc/yum/yum-cron.conf
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
systemctl enable yum-cron
systemctl start yum-cron

echo "セキュリティ強化完了"

# -----------------------------------------------------------------------------
# 基本ツールのインストール
# -----------------------------------------------------------------------------
echo "基本ツールインストール開始..."

# 開発ツール
yum groupinstall -y "Development Tools"

# 便利なツール
yum install -y \
  python3 \
  python3-pip \
  git \
  wget \
  curl \
  vim \
  htop \
  tree \
  unzip \
  jq

echo "基本ツールインストール完了"

# -----------------------------------------------------------------------------
# ログ設定
# -----------------------------------------------------------------------------
echo "ログ設定開始..."

# ログローテーション設定
cat > /etc/logrotate.d/user-data << EOF
/var/log/user-data.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 root root
}
EOF

echo "ログ設定完了"

# -----------------------------------------------------------------------------
# 追加スクリプトの実行
# -----------------------------------------------------------------------------
if [ -n "${additional_scripts}" ]; then
    echo "追加スクリプト実行開始..."
    echo "${additional_scripts}" > /tmp/additional_script.sh
    chmod +x /tmp/additional_script.sh
    /tmp/additional_script.sh
    rm -f /tmp/additional_script.sh
    echo "追加スクリプト実行完了"
fi

# -----------------------------------------------------------------------------
# システム情報の記録
# -----------------------------------------------------------------------------
echo "システム情報記録開始..."
cat > /home/ec2-user/system-info.txt << EOF
EC2 Instance Information
=======================
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)
Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
Project: ${project}
Environment: ${environment}
UserData Completed: $(date)
EOF

echo "システム情報記録完了"

# -----------------------------------------------------------------------------
# 完了通知
# -----------------------------------------------------------------------------
echo "=== Enhanced UserData完了: $(date) ==="
echo "Ansibleによる詳細設定を実行してください"
echo "システム情報: /home/ec2-user/system-info.txt"
echo "ログファイル: /var/log/user-data.log"

# システム情報の表示
echo "システム情報:"
cat /home/ec2-user/system-info.txt 