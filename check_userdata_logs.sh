#!/bin/bash

# UserDataログを確認するスクリプト

echo "=== WordPress EC2 UserDataログ確認 ==="
echo "IP: 54.178.41.253"
echo ""

# SSH接続でログを確認
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@54.178.41.253 "sudo cat /var/log/user-data.log" 2>/dev/null || echo "SSH接続失敗 - ログを確認できません"

echo ""
echo "=== NATインスタンス UserDataログ確認 ==="
echo "IP: 35.73.60.169"
echo ""

# SSH接続でログを確認
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@35.73.60.169 "sudo cat /var/log/user-data.log" 2>/dev/null || echo "SSH接続失敗 - ログを確認できません"

echo ""
echo "=== システムログ確認 ==="
echo ""

# システムログでUserData関連のメッセージを確認
echo "WordPress EC2 システムログ:"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@54.178.41.253 "sudo journalctl -u cloud-init --since '10 minutes ago'" 2>/dev/null || echo "SSH接続失敗"

echo ""
echo "NATインスタンス システムログ:"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@35.73.60.169 "sudo journalctl -u cloud-init --since '10 minutes ago'" 2>/dev/null || echo "SSH接続失敗" 