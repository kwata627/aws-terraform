#!/bin/bash

# WordPress自動デプロイメントシステム初期設定スクリプト

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "=== WordPress自動デプロイメントシステム初期設定 ==="

# 必要なツールの確認
log "必要なツールを確認中..."

# jqの確認
if ! command -v jq &> /dev/null; then
    log "jqをインストール中..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    else
        error_exit "jqのインストールに失敗しました"
    fi
fi

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    log "AWS CLIをインストール中..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# MySQLクライアントの確認
if ! command -v mysql &> /dev/null; then
    log "MySQLクライアントをインストール中..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y mysql-client
    elif command -v yum &> /dev/null; then
        sudo yum install -y mysql
    fi
fi

# 設定ファイルの作成
log "設定ファイルを作成中..."

# Terraformの出力から情報を取得
PROD_EC2_ID=$(terraform output -raw wordpress_public_ip 2>/dev/null || echo "")
PROD_RDS_ID=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
VALID_EC2_ID=$(terraform output -raw validation_private_ip 2>/dev/null || echo "")

# 設定ファイルのテンプレート作成
cat > deployment_config.json << 'EOF'
{
    "production": {
        "ec2_instance_id": "",
        "rds_identifier": "wordpress-project-rds",
        "wordpress_url": "",
        "backup_retention_days": 7
    },
    "validation": {
        "ec2_instance_id": "",
        "rds_identifier": "wordpress-project-rds-validation",
        "wordpress_url": "",
        "test_timeout_minutes": 30
    },
    "deployment": {
        "auto_approve": false,
        "rollback_on_failure": true,
        "notification_email": ""
    }
}
EOF

log "設定ファイルを作成しました: deployment_config.json"
log "以下の情報を設定してください:"
log ""
log "1. production.ec2_instance_id: 本番EC2インスタンスID"
log "2. production.wordpress_url: 本番WordPressサイトのURL"
log "3. validation.ec2_instance_id: 検証EC2インスタンスID"
log "4. validation.wordpress_url: 検証WordPressサイトのURL"
log "5. deployment.notification_email: 通知メールアドレス（オプション）"
log ""

# スクリプトに実行権限を付与
log "スクリプトに実行権限を付与中..."
chmod +x scripts/auto_deployment.sh
chmod +x scripts/rollback.sh

# SSH鍵の設定確認
log "SSH鍵の設定を確認中..."
if [ ! -f ~/.ssh/id_rsa ]; then
    log "SSH鍵が見つかりません。Terraformの出力から取得します..."
    terraform output -raw ssh_private_key > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    log "SSH鍵を設定しました"
fi

# SSH設定ファイルの更新
log "SSH設定ファイルを更新中..."
WORDPRESS_IP=$(terraform output -raw wordpress_public_ip 2>/dev/null || echo "")
if [ -n "$WORDPRESS_IP" ]; then
    # 既存の設定をチェック
    if ! grep -q "Host wordpress-server" ~/.ssh/config 2>/dev/null; then
        cat >> ~/.ssh/config << EOF

Host wordpress-server
  HostName $WORDPRESS_IP
  User ec2-user
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ServerAliveInterval 60
  ServerAliveCountMax 3
EOF
        chmod 600 ~/.ssh/config
        log "SSH設定ファイルを更新しました"
    else
        log "SSH設定ファイルは既に設定済みです"
    fi
else
    log "警告: WordPressサーバーのIPアドレスを取得できませんでした"
fi

# AWS認証情報の確認
log "AWS認証情報を確認中..."
if ! aws sts get-caller-identity &> /dev/null; then
    log "AWS認証情報が設定されていません。設定してください:"
    log "aws configure"
    log "または"
    log "export AWS_ACCESS_KEY_ID=your_access_key"
    log "export AWS_SECRET_ACCESS_KEY=your_secret_key"
    log "export AWS_DEFAULT_REGION=ap-northeast-1"
fi

# テスト用スクリプトの作成
log "テスト用スクリプトを作成中..."
cat > scripts/test_deployment.sh << 'EOF'
#!/bin/bash

# デプロイメントシステムのテストスクリプト

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "=== デプロイメントシステムテスト開始 ==="

# 設定ファイルの確認
if [ ! -f "deployment_config.json" ]; then
    log "エラー: deployment_config.jsonが見つかりません"
    exit 1
fi

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    log "エラー: AWS認証情報が設定されていません"
    exit 1
fi

# 必要なツールの確認
for tool in jq aws mysql curl; do
    if ! command -v $tool &> /dev/null; then
        log "エラー: $toolが見つかりません"
        exit 1
    fi
done

log "✓ 基本的な環境チェック完了"

# 設定値の確認
PROD_EC2_ID=$(jq -r '.production.ec2_instance_id' deployment_config.json)
VALID_EC2_ID=$(jq -r '.validation.ec2_instance_id' deployment_config.json)

if [ "$PROD_EC2_ID" = "null" ] || [ "$PROD_EC2_ID" = "" ]; then
    log "警告: 本番EC2インスタンスIDが設定されていません"
fi

if [ "$VALID_EC2_ID" = "null" ] || [ "$VALID_EC2_ID" = "" ]; then
    log "警告: 検証EC2インスタンスIDが設定されていません"
fi

log "=== デプロイメントシステムテスト完了 ==="
log "設定を完了したら、以下のコマンドでデプロイメントを実行できます:"
log "./scripts/auto_deployment.sh"
EOF

chmod +x scripts/test_deployment.sh

log "=== 初期設定完了 ==="
log ""
log "次のステップ:"
log "1. deployment_config.jsonの設定値を更新"
log "2. ./scripts/test_deployment.sh でテスト実行"
log "3. ./scripts/auto_deployment.sh でデプロイメント実行"
log ""
log "注意: 初回実行前に必ず設定ファイルを確認してください" 