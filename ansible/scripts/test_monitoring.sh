#!/bin/bash

# 監視機能テストスクリプト

echo "=== 監視機能テスト開始 ==="

# 1. インベントリの更新
echo "1. インベントリファイルを更新中..."
python3 generate_inventory.py

# 2. 監視ロールのテスト実行
echo "2. 監視ロールをテスト実行中..."
ansible-playbook playbooks/wordpress_setup.yml --tags monitoring --check

# 3. 監視スクリプトの存在確認
echo "3. 監視スクリプトの存在を確認中..."
ansible wordpress -m stat -a "path=/usr/local/bin/check_wordpress.sh"

# 4. ログディレクトリの確認
echo "4. ログディレクトリの確認中..."
ansible wordpress -m stat -a "path=/var/log/wordpress"

# 5. 監視スクリプトの手動実行テスト
echo "5. 監視スクリプトを手動実行中..."
ansible wordpress -m shell -a "/usr/local/bin/check_wordpress.sh"

# 6. ログファイルの確認
echo "6. ログファイルの確認中..."
ansible wordpress -m shell -a "tail -10 /var/log/wordpress/monitoring.log"

# 7. システムリソースの確認
echo "7. システムリソースの確認中..."
ansible wordpress -m shell -a "df -h"
ansible wordpress -m shell -a "free -h"
ansible wordpress -m shell -a "top -bn1 | head -5"

echo ""
echo "=== 監視機能テスト完了 ===" 