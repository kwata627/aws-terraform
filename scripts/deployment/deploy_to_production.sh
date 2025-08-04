#!/bin/bash

# 本番環境反映スクリプト
# 検証環境でのテスト完了後に本番環境に反映

set -e  # エラー時に停止

# 設定ファイル
CONFIG_FILE="deployment_config.json"
LOG_FILE="deploy_to_production_$(date +%Y%m%d_%H%M%S).log"

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
PROD_WP_URL=$(jq -r '.production.wordpress_url' "$CONFIG_FILE")
VALID_EC2_ID=$(jq -r '.validation.ec2_instance_id' "$CONFIG_FILE")
VALID_RDS_ID=$(jq -r '.validation.rds_identifier' "$CONFIG_FILE")
AUTO_APPROVE=$(jq -r '.deployment.auto_approve' "$CONFIG_FILE")
NOTIFICATION_EMAIL=$(jq -r '.deployment.notification_email' "$CONFIG_FILE")

# 設定の検証
if [ "$PROD_EC2_ID" = "null" ] || [ "$PROD_EC2_ID" = "" ]; then
    error_exit "本番EC2インスタンスIDが設定されていません"
fi

if [ "$VALID_EC2_ID" = "null" ] || [ "$VALID_EC2_ID" = "" ]; then
    error_exit "検証EC2インスタンスIDが設定されていません"
fi

log "=== 本番環境反映開始 ==="

# 検証環境の状態確認
log "検証環境の状態を確認中..."
VALID_STATUS=$(aws ec2 describe-instances --instance-ids "$VALID_EC2_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
if [ "$VALID_STATUS" != "running" ]; then
    error_exit "検証環境が起動していません。先に prepare_validation.sh を実行してください。"
fi

log "検証環境が起動中です"

# ユーザー確認（自動承認でない場合）
if [ "$AUTO_APPROVE" != "true" ]; then
    log "検証環境でのテストが完了しました。"
    log "本番環境への反映を続行しますか？ (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "デプロイメントを中止しました"
        exit 0
    fi
fi

# ステップ1: 本番環境のバックアップ作成
log "ステップ1: 本番環境のバックアップを作成中..."
BACKUP_FILE="backup_production_$(date +%Y%m%d_%H%M%S).sql"
mysqldump -h "$(aws rds describe-db-instances --db-instance-identifier "$PROD_RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)" \
    -u admin -p"breadhouse" wordpress > "$BACKUP_FILE"
log "バックアップ完了: $BACKUP_FILE"

# 本番環境のWordPressファイルのバックアップ
log "WordPressファイルのバックアップを作成中..."
PROD_IP=$(aws ec2 describe-instances --instance-ids "$PROD_EC2_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "sudo tar -czf /tmp/wordpress_backup.tar.gz -C /var/www/html ."
scp -o StrictHostKeyChecking=no ec2-user@"$PROD_IP":/tmp/wordpress_backup.tar.gz "wordpress_files_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

# ステップ2: 検証環境から本番環境へのデータ同期
log "ステップ2: 検証環境から本番環境へのデータ同期中..."

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
VALID_IP=$(aws ec2 describe-instances --instance-ids "$VALID_EC2_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "mkdir -p /tmp/wordpress_sync"
scp -o StrictHostKeyChecking=no -r ec2-user@"$VALID_IP":/var/www/html/* ec2-user@"$PROD_IP":/tmp/wordpress_sync/
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "sudo rsync -av /tmp/wordpress_sync/ /var/www/html/ && sudo chown -R apache:apache /var/www/html/"

log "WordPressファイル同期完了"

# ステップ3: 本番環境の動作確認
log "ステップ3: 本番環境の動作確認中..."

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

# ステップ4: 検証環境の停止
log "ステップ4: 検証環境を停止中..."

# 検証用EC2の停止
aws ec2 stop-instances --instance-ids "$VALID_EC2_ID"
log "検証用EC2停止完了"

# 検証用RDSの停止
aws rds stop-db-instance --db-instance-identifier "$VALID_RDS_ID"
log "検証用RDS停止完了"

# ステップ5: クリーンアップ
log "ステップ5: 一時ファイルのクリーンアップ中..."
rm -f validation_dump.sql
ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "rm -rf /tmp/wordpress_sync"

log "=== 本番環境反映完了 ==="

# 通知メールの送信（設定されている場合）
if [ "$NOTIFICATION_EMAIL" != "null" ] && [ "$NOTIFICATION_EMAIL" != "" ]; then
    echo "WordPress本番環境への反映が正常に完了しました。" | mail -s "WordPress本番反映完了" "$NOTIFICATION_EMAIL"
fi

log "デプロイメントログ: $LOG_FILE"
log ""
log "本番環境URL: $PROD_WP_URL"
log "本番環境管理画面: $PROD_WP_URL/wp-admin" 