#!/bin/bash

# WordPress 500エラー調査スクリプト
# 使用方法: ./wordpress_debug.sh [サーバーIP]

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WordPress 500エラー調査スクリプト ===${NC}"

# サーバーIPの設定
if [ -n "$1" ]; then
    SERVER_IP="$1"
else
    echo -e "${YELLOW}サーバーIPを入力してください:${NC}"
    read -r SERVER_IP
fi

echo -e "${GREEN}調査対象サーバー: ${SERVER_IP}${NC}"

# 1. 基本的な接続確認
echo -e "\n${BLUE}1. 基本的な接続確認${NC}"
if ping -c 1 "$SERVER_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ サーバーに接続可能${NC}"
else
    echo -e "${RED}✗ サーバーに接続できません${NC}"
    exit 1
fi

# 2. HTTP応答確認
echo -e "\n${BLUE}2. HTTP応答確認${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}")
echo -e "HTTPステータス: ${HTTP_STATUS}"

if [ "$HTTP_STATUS" = "500" ]; then
    echo -e "${RED}✗ 500エラーが確認されました${NC}"
elif [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ 正常に応答しています${NC}"
else
    echo -e "${YELLOW}⚠ 予期しないステータス: ${HTTP_STATUS}${NC}"
fi

# 3. ログファイルの確認
echo -e "\n${BLUE}3. ログファイルの確認${NC}"

# Apache エラーログ
echo -e "\n${YELLOW}Apache エラーログ (最新10行):${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "sudo tail -n 10 /var/log/httpd/wordpress_error.log 2>/dev/null || echo 'ログファイルが見つかりません'"

# PHP エラーログ
echo -e "\n${YELLOW}PHP エラーログ (最新10行):${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "sudo tail -n 10 /var/log/php_errors.log 2>/dev/null || echo 'ログファイルが見つかりません'"

# WordPress デバッグログ
echo -e "\n${YELLOW}WordPress デバッグログ (最新10行):${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "sudo tail -n 10 /var/www/html/wp-content/debug.log 2>/dev/null || echo 'デバッグログが見つかりません'"

# 4. サービス状態確認
echo -e "\n${BLUE}4. サービス状態確認${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "echo 'Apache ステータス:' && sudo systemctl status httpd --no-pager -l && echo 'PHP-FPM ステータス:' && sudo systemctl status php-fpm --no-pager -l 2>/dev/null || echo 'PHP-FPM は実行されていません'"

# 5. ファイル権限確認
echo -e "\n${BLUE}5. ファイル権限確認${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "echo 'WordPress ディレクトリ権限:' && ls -la /var/www/html/ | head -5 && echo 'wp-config.php 権限:' && ls -la /var/www/html/wp-config.php 2>/dev/null || echo 'wp-config.php が見つかりません'"

# 6. データベース接続確認
echo -e "\n${BLUE}6. データベース接続確認${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "echo 'MySQL ステータス:' && sudo systemctl status mysqld --no-pager -l 2>/dev/null || echo 'MySQL は実行されていません'"

# 7. wp-config.php の設定確認
echo -e "\n${BLUE}7. wp-config.php の設定確認${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "echo 'データベース設定:' && sudo grep -E 'DB_(NAME|USER|PASSWORD|HOST)' /var/www/html/wp-config.php 2>/dev/null || echo 'wp-config.php が見つかりません'"

# 8. PHP設定確認
echo -e "\n${BLUE}8. PHP設定確認${NC}"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "ec2-user@${SERVER_IP}" \
    "echo 'PHP バージョン:' && php -v && echo 'PHP 設定:' && php -i | grep -E '(display_errors|log_errors|error_log)'"

echo -e "\n${BLUE}=== 調査完了 ===${NC}"
echo -e "${YELLOW}詳細なログを確認するには、サーバーに直接SSH接続してログファイルを確認してください。${NC}"
