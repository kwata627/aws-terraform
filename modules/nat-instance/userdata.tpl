#!/bin/bash
# =============================================================================
# NAT Instance UserData Template
# =============================================================================
# 
# このスクリプトはNATインスタンスの初期設定を行います。
# SSH設定、NAT設定、セキュリティ強化を含みます。
#
# パラメータ:
# - ssh_public_key: SSH公開鍵
# - ssh_private_key: SSH秘密鍵
# - project: プロジェクト名
# - environment: 環境名
# - vpc_cidr: VPCのCIDRブロック
# - additional_scripts: 追加スクリプト
# =============================================================================

# ログ設定
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== NAT UserData開始: $(date) ==="
echo "プロジェクト: ${project}"
echo "環境: ${environment}"
echo "VPC CIDR: ${vpc_cidr}"

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
echo "${ssh_public_key}" > /home/ec2-user/.ssh/authorized_keys
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
echo "SSH公開鍵設定完了"

# SSH秘密鍵の配置（検証用インスタンス接続用）
echo "SSH秘密鍵設定開始..."
cat > /home/ec2-user/.ssh/id_rsa << 'INNER_EOF'
${ssh_private_key}
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

# -----------------------------------------------------------------------------
# NAT設定
# -----------------------------------------------------------------------------
echo "NAT設定開始..."

# IPフォワーディングの有効化
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "IPフォワーディング有効化完了"

# iptablesルールの設定
iptables -t nat -A POSTROUTING -o eth0 -s ${vpc_cidr} -j MASQUERADE
echo "iptables NATルール設定完了"

# iptablesルールの永続化
yum install -y iptables-services
systemctl enable iptables
systemctl start iptables

# 現在のルールを保存
iptables-save > /etc/sysconfig/iptables
echo "iptablesルール永続化完了"

# -----------------------------------------------------------------------------
# セキュリティ強化
# -----------------------------------------------------------------------------
echo "セキュリティ強化開始..."

# セキュリティアップデート
yum install -y yum-cron
sed -i 's/update_cmd = default/update_cmd = security/' /etc/yum/yum-cron.conf
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
systemctl enable yum-cron
systemctl start yum-cron

# ファイアウォール設定（必要に応じて）
# systemctl enable firewalld
# systemctl start firewalld

echo "セキュリティ強化完了"

# -----------------------------------------------------------------------------
# 基本ツールのインストール
# -----------------------------------------------------------------------------
echo "基本ツールインストール開始..."

# 便利なツール
yum install -y \
  wget \
  curl \
  vim \
  htop \
  tree \
  unzip \
  jq \
  net-tools

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
# NAT設定の確認
# -----------------------------------------------------------------------------
echo "NAT設定確認開始..."

# IPフォワーディングの確認
echo "IPフォワーディング状態:"
cat /proc/sys/net/ipv4/ip_forward

# iptablesルールの確認
echo "iptables NATルール:"
iptables -t nat -L POSTROUTING -n

# ネットワークインターフェースの確認
echo "ネットワークインターフェース:"
ip addr show

echo "NAT設定確認完了"

# -----------------------------------------------------------------------------
# システム情報の記録
# -----------------------------------------------------------------------------
echo "システム情報記録開始..."
cat > /home/ec2-user/nat-system-info.txt << EOF
NAT Instance Information
========================
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)
Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
Project: ${project}
Environment: ${environment}
VPC CIDR: ${vpc_cidr}
UserData Completed: $(date)
EOF

echo "システム情報記録完了"

# -----------------------------------------------------------------------------
# 完了通知
# -----------------------------------------------------------------------------
echo "=== NAT UserData完了: $(date) ==="
echo "NATインスタンスの設定が完了しました"
echo "システム情報: /home/ec2-user/nat-system-info.txt"
echo "ログファイル: /var/log/user-data.log"

# システム情報の表示
echo "システム情報:"
cat /home/ec2-user/nat-system-info.txt 