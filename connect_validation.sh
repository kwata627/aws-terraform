#!/bin/bash

# 検証用インスタンスにNAT経由で接続するスクリプト

# Terraformの出力からIPアドレスを取得
NAT_IP=$(terraform output -raw nat_instance_public_ip)
VALIDATION_IP=$(terraform output -raw validation_private_ip)

echo "=== 検証用インスタンス接続スクリプト ==="
echo "NATインスタンスIP: $NAT_IP"
echo "検証用インスタンスIP: $VALIDATION_IP"
echo ""

# SSH鍵の確認
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "エラー: SSH鍵が見つかりません (~/.ssh/id_rsa)"
    echo "以下のコマンドでSSH鍵を保存してください:"
    echo "terraform output -raw ssh_private_key > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"
    exit 1
fi

echo "検証用インスタンスに接続します..."
echo "接続先: ec2-user@$VALIDATION_IP (NAT経由: $NAT_IP)"
echo ""

# NATインスタンス経由で検証用インスタンスに接続
ssh -i ~/.ssh/id_rsa -o ProxyCommand="ssh -i ~/.ssh/id_rsa -W %h:%p ec2-user@$NAT_IP" ec2-user@$VALIDATION_IP 