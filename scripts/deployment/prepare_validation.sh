#!/bin/bash

# 検証環境準備スクリプト
# 本番環境のスナップショット作成から検証環境のテスト完了まで

set -e  # エラー時に停止

# 設定ファイル
CONFIG_FILE="deployment_config.json"
LOG_FILE="prepare_validation_$(date +%Y%m%d_%H%M%S).log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "エラー: $1"
    exit 1
}

# 設定ファイルの確認
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "設定ファイルが見つかりません: $CONFIG_FILE"
fi

# 設定の読み込み
PROD_EC2_ID=$(jq -r '.production.ec2_instance_id' "$CONFIG_FILE")
PROD_RDS_ID=$(jq -r '.production.rds_identifier' "$CONFIG_FILE")
VALID_EC2_ID=$(jq -r '.validation.ec2_instance_id' "$CONFIG_FILE")
VALID_RDS_ID=$(jq -r '.validation.rds_identifier' "$CONFIG_FILE")
VALID_WP_URL=$(jq -r '.validation.wordpress_url' "$CONFIG_FILE")
VALID_DB_PASSWORD=$(jq -r '.validation.db_password' "$CONFIG_FILE")

# 設定の検証
if [ "$PROD_EC2_ID" = "null" ] || [ "$PROD_EC2_ID" = "" ]; then
    error_exit "本番EC2インスタンスIDが設定されていません"
fi

if [ "$VALID_EC2_ID" = "null" ] || [ "$VALID_EC2_ID" = "" ]; then
    error_exit "検証EC2インスタンスIDが設定されていません"
fi

log "=== 検証環境準備開始 ==="

# ステップ1: 本番環境のスナップショット作成
log "ステップ1: 本番環境のスナップショットを作成中..."
SNAPSHOT_ID="wp-production-$(date +%Y%m%d-%H%M%S)"

# RDSスナップショットの作成
aws rds create-db-snapshot \
    --db-instance-identifier "$PROD_RDS_ID" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --tags Key=Purpose,Value=DeploymentBackup Key=Date,Value=$(date +%Y-%m-%d)

log "RDSスナップショット作成完了: $SNAPSHOT_ID"

# ステップ2: 検証環境の起動
log "ステップ2: 検証環境を起動中..."

# 検証用EC2の起動
aws ec2 start-instances --instance-ids "$VALID_EC2_ID"
log "検証用EC2起動完了"

# 検証用RDSの起動（スナップショットから復元）
if aws rds describe-db-instances --db-instance-identifier "$VALID_RDS_ID" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null | grep -q "available"; then
    log "検証用RDSは既に起動しています"
else
    log "検証用RDSをスナップショットから復元中..."
    aws rds restore-db-instance-from-db-snapshot \
        --db-instance-identifier "$VALID_RDS_ID" \
        --db-snapshot-identifier "$SNAPSHOT_ID" \
        --db-instance-class db.t3.micro \
        --no-multi-az \
        --tags Key=Purpose,Value=Validation Key=Date,Value=$(date +%Y-%m-%d)
fi

# ステップ3: 検証環境の準備完了待機
log "ステップ3: 検証環境の準備完了を待機中..."

# EC2の準備完了待機
log "検証用EC2の準備完了を待機中..."
aws ec2 wait instance-running --instance-ids "$VALID_EC2_ID"
aws ec2 wait instance-status-ok --instance-ids "$VALID_EC2_ID"

# RDSの準備完了待機
log "検証用RDSの準備完了を待機中..."
aws rds wait db-instance-available --db-instance-identifier "$VALID_RDS_ID"

log "検証環境の準備完了"

# ステップ4: 検証環境でのテスト実行
log "ステップ4: 検証環境でのテストを実行中..."

# 検証環境のIPアドレス取得
VALID_IP=$(aws ec2 describe-instances --instance-ids "$VALID_EC2_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
log "検証環境IP: $VALID_IP"

# WordPressサイトの動作確認
log "WordPressサイトの動作確認中..."
if curl -f -s "$VALID_WP_URL" > /dev/null; then
    log "✓ WordPressサイトが正常に動作しています"
else
    error_exit "✗ WordPressサイトにアクセスできません"
fi

# 管理画面の動作確認
log "管理画面の動作確認中..."
if curl -f -s "$VALID_WP_URL/wp-admin" > /dev/null; then
    log "✓ 管理画面にアクセスできます"
else
    error_exit "✗ 管理画面にアクセスできません"
fi

# データベース接続確認
log "データベース接続確認中..."
VALID_RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$VALID_RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)
if mysql -h "$VALID_RDS_ENDPOINT" -u admin -p"$VALID_DB_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
    log "✓ データベース接続が正常です"
else
    error_exit "✗ データベース接続に失敗しました"
fi

log "検証環境でのテスト完了"

# 検証環境の情報を表示
log "=== 検証環境準備完了 ==="
log "検証環境IP: $VALID_IP"
log "検証環境URL: $VALID_WP_URL"
log "検証環境管理画面: $VALID_WP_URL/wp-admin"
log ""
log "検証環境でテストを実行してください。"
log "テスト完了後、以下のコマンドで本番環境に反映できます："
log "./scripts/deploy_to_production.sh"
log ""
log "検証環境ログ: $LOG_FILE" 