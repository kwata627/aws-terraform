#!/bin/bash

# WordPress環境テストスクリプト

set -e

echo "=== WordPress環境テスト開始 ==="

# 1. インベントリの更新
echo "1. インベントリファイルを更新中..."
python3 generate_inventory.py

# 2. 接続テスト
echo "2. サーバーへの接続をテスト中..."
ansible wordpress -m ping

# 3. システム情報の取得
echo "3. システム情報を取得中..."
ansible wordpress -m setup -a "filter=ansible_distribution*"

# 4. サービス状態の確認
echo "4. サービス状態を確認中..."
ansible wordpress -m service_facts

# 5. ファイル存在確認
echo "5. 重要なファイルの存在を確認中..."
ansible wordpress -m stat -a "path=/var/www/html/wp-config.php"
ansible wordpress -m stat -a "path=/etc/httpd/conf/httpd.conf"
ansible wordpress -m stat -a "path=/etc/php.ini"

# 6. ポート確認
echo "6. ポートの状態を確認中..."
ansible wordpress -m wait_for -a "port=80 timeout=5"
ansible wordpress -m wait_for -a "port=22 timeout=5"

# 7. WordPressアクセステスト
echo "7. WordPressアクセスをテスト中..."
WORDPRESS_IP=$(terraform output -raw wordpress_public_ip)
if curl -f -s "https://$WORDPRESS_IP" > /dev/null; then
    echo "✅ WordPressサイトにアクセス可能"
else
    echo "❌ WordPressサイトにアクセス不可"
fi

# 8. データベース接続テスト
echo "8. データベース接続をテスト中..."
ansible wordpress -m mysql_query -a "login_host={{ rds_host }} login_port={{ rds_port }} login_user={{ wp_db_user }} login_password={{ wp_db_password }} login_db={{ wp_db_name }} query='SELECT 1'" --extra-vars "@group_vars/all/terraform_vars.yml"

echo ""
echo "=== テスト完了 ===" 