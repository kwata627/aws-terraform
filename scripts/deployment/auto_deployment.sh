#!/bin/bash

# WordPress自動デプロイメントスクリプト
# 検証環境でのテスト後に本番環境に自動反映

set -e  # エラー時に停止

# 設定ファイル
CONFIG_FILE="deployment_config.json"
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

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
    log "設定ファイルが見つかりません: $CONFIG_FILE"
    log "設定ファイルを作成します..."
    cat > "$CONFIG_FILE" << 'EOF'
{
    "production": {
        "ec2_instance_id": "",
        "rds_identifier": "wp-shamo-rds",
        "wordpress_url": "",
        "backup_retention_days": 7
    },
    "validation": {
        "ec2_instance_id": "",
        "rds_identifier": "wp-shamo-rds-validation",
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
    log "設定ファイルを作成しました。値を設定してください。"
    exit 1
fi

# 設定の読み込み
PROD_EC2_ID=$(jq -r '.production.ec2_instance_id' "$CONFIG_FILE")
PROD_RDS_ID=$(jq -r '.production.rds_identifier' "$CONFIG_FILE")
PROD_WP_URL=$(jq -r '.production.wordpress_url' "$CONFIG_FILE")
VALID_EC2_ID=$(jq -r '.validation.ec2_instance_id' "$CONFIG_FILE")
VALID_RDS_ID=$(jq -r '.validation.rds_identifier' "$CONFIG_FILE")
VALID_WP_URL=$(jq -r '.validation.wordpress_url' "$CONFIG_FILE")
AUTO_APPROVE=$(jq -r '.deployment.auto_approve' "$CONFIG_FILE")
ROLLBACK_ON_FAILURE=$(jq -r '.deployment.rollback_on_failure' "$CONFIG_FILE")
NOTIFICATION_EMAIL=$(jq -r '.deployment.notification_email' "$CONFIG_FILE")

# 設定の検証
if [ "$PROD_EC2_ID" = "null" ] || [ "$PROD_EC2_ID" = "" ]; then
    error_exit "本番EC2インスタンスIDが設定されていません"
fi

if [ "$VALID_EC2_ID" = "null" ] || [ "$VALID_EC2_ID" = "" ]; then
    error_exit "検証EC2インスタンスIDが設定されていません"
fi

log "=== WordPress自動デプロイメント開始 ==="

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
if mysql -h "$VALID_RDS_ENDPOINT" -u admin -p"breadhouse" -e "SELECT 1;" 2>/dev/null; then
    log "✓ データベース接続が正常です"
else
    error_exit "✗ データベース接続に失敗しました"
fi

log "検証環境でのテスト完了"

# ステップ5: ユーザー確認（自動承認でない場合）
if [ "$AUTO_APPROVE" != "true" ]; then
    log "検証環境でのテストが完了しました。"
    log "本番環境への反映を続行しますか？ (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "デプロイメントを中止しました"
        exit 0
    fi
fi

# ステップ6: 本番環境への反映
log "ステップ6: 本番環境への反映を開始..."

# 本番環境のバックアップ作成
log "本番環境のバックアップを作成中..."
BACKUP_FILE="backup_production_$(date +%Y%m%d_%H%M%S).sql"
mysqldump -h "$(aws rds describe-db-instances --db-instance-identifier "$PROD_RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)" \
    -u admin -p"breadhouse" wordpress > "$BACKUP_FILE"
log "バックアップ完了: $BACKUP_FILE"

# 本番環境のWordPressファイルのバックアップ
log "WordPressファイルのバックアップを作成中..."
PROD_IP=$(aws ec2 describe-instances --instance-ids "$PROD_EC2_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
tar -czf "wordpress_files_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C /tmp wordpress_backup
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "sudo tar -czf /tmp/wordpress_backup.tar.gz -C /var/www/html ."

# 検証環境から本番環境へのデータ同期
log "検証環境から本番環境へのデータ同期中..."

# データベースの同期
log "データベースの同期中..."
VALID_RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$VALID_RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)
PROD_RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$PROD_RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)

# 検証環境のデータベースをダンプ
mysqldump -h "$VALID_RDS_ENDPOINT" -u admin -p"breadhouse" wordpress > validation_dump.sql

# 本番環境にデータを復元
mysql -h "$PROD_RDS_ENDPOINT" -u admin -p"breadhouse" wordpress < validation_dump.sql

log "データベース同期完了"

# WordPressファイルの同期
log "WordPressファイルの同期中..."
scp -o StrictHostKeyChecking=no -r ec2-user@"$VALID_IP":/var/www/html/* ec2-user@"$PROD_IP":/tmp/wordpress_sync/
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "sudo rsync -av /tmp/wordpress_sync/ /var/www/html/ && sudo chown -R apache:apache /var/www/html/"

log "WordPressファイル同期完了"

# ステップ7: 本番環境の動作確認
log "ステップ7: 本番環境の動作確認中..."

# サイトの動作確認
if curl -f -s "$PROD_WP_URL" > /dev/null; then
    log "✓ 本番サイトが正常に動作しています"
else
    error_exit "✗ 本番サイトにアクセスできません"
fi

# 管理画面の動作確認
if curl -f -s "$PROD_WP_URL/wp-admin" > /dev/null; then
    log "✓ 本番管理画面にアクセスできます"
else
    error_exit "✗ 本番管理画面にアクセスできません"
fi

log "本番環境の動作確認完了"

# ステップ8: 検証環境の停止
log "ステップ8: 検証環境を停止中..."

# 検証用EC2の停止
aws ec2 stop-instances --instance-ids "$VALID_EC2_ID"
log "検証用EC2停止完了"

# 検証用RDSの停止
aws rds stop-db-instance --db-instance-identifier "$VALID_RDS_ID"
log "検証用RDS停止完了"

# ステップ9: クリーンアップ
log "ステップ9: 一時ファイルのクリーンアップ中..."
rm -f validation_dump.sql
rm -f /tmp/wordpress_sync -rf

log "=== WordPress自動デプロイメント完了 ==="

# 通知メールの送信（設定されている場合）
if [ "$NOTIFICATION_EMAIL" != "null" ] && [ "$NOTIFICATION_EMAIL" != "" ]; then
    echo "WordPress自動デプロイメントが正常に完了しました。" | mail -s "WordPressデプロイメント完了" "$NOTIFICATION_EMAIL"
fi

log "デプロイメントログ: $LOG_FILE" 