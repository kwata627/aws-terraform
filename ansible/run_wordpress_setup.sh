#!/bin/bash

# WordPress環境構築実行スクリプト

echo "=== WordPress環境構築開始 ==="

# 1. インベントリの更新
echo "1. インベントリファイルを更新中..."
cd ansible
python3 generate_inventory.py

# 2. 変数の確認
echo "2. 変数設定を確認中..."
if [ ! -f "group_vars/wordpress.yml" ]; then
    echo "エラー: group_vars/wordpress.yml が見つかりません"
    exit 1
fi

# 3. 接続テスト
echo "3. サーバーへの接続をテスト中..."
ansible wordpress -m ping

if [ $? -ne 0 ]; then
    echo "エラー: WordPressサーバーへの接続に失敗しました"
    echo "SSH鍵の設定を確認してください"
    exit 1
fi

# 4. WordPress環境構築の実行
echo "4. WordPress環境を構築中..."
ansible-playbook playbooks/wordpress_setup.yml

if [ $? -eq 0 ]; then
    echo "=== WordPress環境構築完了 ==="
    echo "WordPressサイトにアクセスしてください:"
    echo "http://$(terraform output -raw wordpress_public_ip)"
else
    echo "エラー: WordPress環境構築に失敗しました"
    exit 1
fi 