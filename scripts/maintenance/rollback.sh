#!/bin/bash

# WordPressロールバックスクリプト
# デプロイメント失敗時に本番環境を元の状態に戻す

set -e

# 設定ファイル
CONFIG_FILE="deployment_config.json"
LOG_FILE="rollback_$(date +%Y%m%d_%H%M%S).log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "エラー: $1"
    exit 1
}

# 設定の読み込み
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "設定ファイルが見つかりません: $CONFIG_FILE"
fi

PROD_EC2_ID=$(jq -r '.production.ec2_instance_id' "$CONFIG_FILE")
PROD_RDS_ID=$(jq -r '.production.rds_identifier' "$CONFIG_FILE")
PROD_WP_URL=$(jq -r '.production.wordpress_url' "$CONFIG_FILE")

log "=== WordPressロールバック開始 ==="

# 最新のスナップショットを取得
log "最新のスナップショットを確認中..."
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
    --db-instance-identifier "$PROD_RDS_ID" \
    --query 'DBSnapshots[?SnapshotType==`manual`] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
    --output text)

if [ "$LATEST_SNAPSHOT" = "None" ] || [ "$LATEST_SNAPSHOT" = "" ]; then
    error_exit "利用可能なスナップショットが見つかりません"
fi

log "使用するスナップショット: $LATEST_SNAPSHOT"

# 本番環境の停止
log "本番環境を停止中..."
aws rds stop-db-instance --db-instance-identifier "$PROD_RDS_ID"

# スナップショットから復元
log "スナップショットから復元中..."
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "$PROD_RDS_ID" \
    --db-snapshot-identifier "$LATEST_SNAPSHOT" \
    --db-instance-class db.t3.micro \
    --no-multi-az

# 復元完了待機
log "復元完了を待機中..."
aws rds wait db-instance-available --db-instance-identifier "$PROD_RDS_ID"

# WordPressファイルの復元
log "WordPressファイルを復元中..."
PROD_IP=$(aws ec2 describe-instances --instance-ids "$PROD_EC2_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# 最新のバックアップファイルを探す
BACKUP_FILE=$(ls -t wordpress_files_backup_*.tar.gz 2>/dev/null | head -1)

if [ -n "$BACKUP_FILE" ]; then
    log "バックアップファイルを復元中: $BACKUP_FILE"
    scp -o StrictHostKeyChecking=no "$BACKUP_FILE" ec2-user@"$PROD_IP":/tmp/
    ssh -o StrictHostKeyChecking=no ec2-user@"$PROD_IP" "sudo tar -xzf /tmp/$(basename "$BACKUP_FILE") -C /var/www/html/ && sudo chown -R apache:apache /var/www/html/"
else
    log "WordPressファイルのバックアップが見つかりません。手動で復元してください。"
fi

# 動作確認
log "復元後の動作確認中..."
sleep 30  # システムの安定化を待つ

if curl -f -s "$PROD_WP_URL" > /dev/null; then
    log "✓ ロールバックが正常に完了しました"
else
    error_exit "✗ ロールバック後の動作確認に失敗しました"
fi

log "=== WordPressロールバック完了 ==="
log "ロールバックログ: $LOG_FILE" 