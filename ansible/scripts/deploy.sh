#!/bin/bash

# WordPress環境デプロイメントスクリプト

set -e

# 設定
ENVIRONMENT=${1:-production}
PLAYBOOK=${2:-playbooks/wordpress_setup.yml}
VERBOSE=${3:-false}

echo "=== WordPress環境デプロイメント開始 ==="
echo "環境: $ENVIRONMENT"
echo "プレイブック: $PLAYBOOK"
echo "詳細出力: $VERBOSE"
echo ""

# 1. 環境変数の設定
if [ "$ENVIRONMENT" = "production" ]; then
    ENV_FILE="environments/production.yml"
elif [ "$ENVIRONMENT" = "development" ]; then
    ENV_FILE="environments/development.yml"
else
    echo "エラー: 無効な環境 '$ENVIRONMENT'"
    echo "使用可能な環境: production, development"
    exit 1
fi

# 2. インベントリの更新
echo "1. インベントリファイルを更新中..."
python3 generate_inventory.py

if [ $? -ne 0 ]; then
    echo "エラー: インベントリの更新に失敗しました"
    exit 1
fi

# 3. 接続テスト
echo "2. サーバーへの接続をテスト中..."
ansible wordpress -m ping

if [ $? -ne 0 ]; then
    echo "警告: WordPressサーバーへの接続に失敗しました"
    echo "SSH鍵の設定を確認してください"
    echo "インフラがまだ構築中の可能性があります"
    echo "続行しますか？ (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 4. 環境変数の読み込み
if [ -f "$ENV_FILE" ]; then
    echo "3. 環境設定を読み込み中: $ENV_FILE"
    export ANSIBLE_EXTRA_VARS="@$ENV_FILE"
fi

# 5. プレイブックの実行
echo "4. プレイブックを実行中..."
if [ "$VERBOSE" = "true" ]; then
    ansible-playbook -v "$PLAYBOOK"
else
    ansible-playbook "$PLAYBOOK"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "=== デプロイメント完了 ==="
    echo "WordPressサイトにアクセスしてください:"
    echo "http://$(terraform output -raw wordpress_public_ip)"
else
    echo ""
    echo "エラー: デプロイメントに失敗しました"
    exit 1
fi 