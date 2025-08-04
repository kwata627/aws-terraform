#!/bin/bash

# 環境変数を使用したSSH接続許可IP更新スクリプト

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 環境変数からIPアドレスを取得
if [ -z "$SSH_ALLOWED_IP" ]; then
    log "環境変数 SSH_ALLOWED_IP が設定されていません"
    log "使用方法:"
    log "export SSH_ALLOWED_IP=your.ip.address.here"
    log "./scripts/update_ssh_cidr_env.sh"
    exit 1
fi

# CIDR形式に変換
CURRENT_CIDR="${SSH_ALLOWED_IP}/32"

log "設定されたIPアドレス: $SSH_ALLOWED_IP"
log "CIDR形式: $CURRENT_CIDR"

# terraform.tfvarsの現在の設定を確認
CURRENT_CIDR_IN_FILE=$(grep "ssh_allowed_cidr" terraform.tfvars | cut -d'"' -f2)

if [ "$CURRENT_CIDR" = "$CURRENT_CIDR_IN_FILE" ]; then
    log "IPアドレスは変更されていません"
    exit 0
fi

log "IPアドレスが変更されました。terraform.tfvarsを更新します..."

# terraform.tfvarsを更新
sed -i "s|ssh_allowed_cidr = \".*\"|ssh_allowed_cidr = \"$CURRENT_CIDR\"|" terraform.tfvars

log "terraform.tfvarsを更新しました"

# Terraformの適用確認
log "Terraformの変更を確認します..."
terraform plan -target=module.security

echo ""
log "以下のコマンドで変更を適用してください:"
echo "terraform apply -target=module.security" 