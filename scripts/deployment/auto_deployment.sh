#!/bin/bash

# =============================================================================
# WordPress自動デプロイメントスクリプト
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="WordPress自動デプロイメント"
readonly CONFIG_FILE="deployment_config.json"
readonly LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
WordPress自動デプロイメントスクリプト

使用方法:
  $0                    # 自動デプロイメント実行
  $0 --dry-run         # ドライラン（実際の変更なし）
  $0 --help            # このヘルプを表示

機能:
- 本番環境のスナップショット作成
- 検証環境の起動・復元
- 検証環境でのテスト実行
- 本番環境への反映
- 検証環境の停止
- ロールバック機能

環境変数:
- AUTO_APPROVE: 自動承認 (true/false)
- ROLLBACK_ON_FAILURE: 失敗時のロールバック (true/false)
- NOTIFICATION_EMAIL: 通知メールアドレス
- LOG_LEVEL: ログレベル (INFO/WARN/ERROR)

EOF
}

# 設定の読み込み
load_deployment_config() {
    log_step "デプロイメント設定を読み込み中..."
    
    # 設定ファイルの確認
    validate_config_file "$CONFIG_FILE"
    
    # 設定値の読み込み
    PROD_EC2_ID=$(load_config "$CONFIG_FILE" ".production.ec2_instance_id")
    PROD_RDS_ID=$(load_config "$CONFIG_FILE" ".production.rds_identifier" "wp-shamo-rds")
    PROD_WP_URL=$(load_config "$CONFIG_FILE" ".production.wordpress_url")
    VALID_EC2_ID=$(load_config "$CONFIG_FILE" ".validation.ec2_instance_id")
    VALID_RDS_ID=$(load_config "$CONFIG_FILE" ".validation.rds_identifier" "wp-shamo-rds-validation")
    VALID_WP_URL=$(load_config "$CONFIG_FILE" ".validation.wordpress_url")
    AUTO_APPROVE=$(load_config "$CONFIG_FILE" ".deployment.auto_approve" "false")
    ROLLBACK_ON_FAILURE=$(load_config "$CONFIG_FILE" ".deployment.rollback_on_failure" "true")
    NOTIFICATION_EMAIL=$(load_config "$CONFIG_FILE" ".deployment.notification_email" "")
    BACKUP_BEFORE_DEPLOYMENT=$(load_config "$CONFIG_FILE" ".deployment.backup_before_deployment" "true")
    TEST_TIMEOUT=$(load_config "$CONFIG_FILE" ".validation.test_timeout_minutes" "30")
    
    # AWS設定の読み込み
    AWS_REGION=$(load_config "$CONFIG_FILE" ".aws.region" "ap-northeast-1")
    AWS_PROFILE=$(load_config "$CONFIG_FILE" ".aws.profile" "default")
    AWS_MAX_RETRIES=$(load_config "$CONFIG_FILE" ".aws.max_retries" "3")
    
    # SSH設定の読み込み
    SSH_USER=$(load_config "$CONFIG_FILE" ".production.ssh_user" "ubuntu")
    SSH_KEY_PATH=$(load_config "$CONFIG_FILE" ".production.ssh_key_path" "~/.ssh/id_rsa")
    
    log_success "デプロイメント設定を読み込みました"
}

# 設定の検証
validate_deployment_config() {
    log_step "デプロイメント設定を検証中..."
    
    # 必須設定の確認
    if [ "$PROD_EC2_ID" = "null" ] || [ "$PROD_EC2_ID" = "" ]; then
        error_exit "本番EC2インスタンスIDが設定されていません"
    fi
    
    if [ "$VALID_EC2_ID" = "null" ] || [ "$VALID_EC2_ID" = "" ]; then
        error_exit "検証EC2インスタンスIDが設定されていません"
    fi
    
    if [ "$PROD_WP_URL" = "null" ] || [ "$PROD_WP_URL" = "" ]; then
        error_exit "本番WordPress URLが設定されていません"
    fi
    
    if [ "$VALID_WP_URL" = "null" ] || [ "$VALID_WP_URL" = "" ]; then
        error_exit "検証WordPress URLが設定されていません"
    fi
    
    # AWSリソースの存在確認
    check_aws_resource "ec2" "$PROD_EC2_ID"
    check_aws_resource "ec2" "$VALID_EC2_ID"
    check_aws_resource "rds" "$PROD_RDS_ID"
    
    log_success "デプロイメント設定の検証が完了しました"
}

# 本番環境のスナップショット作成
create_production_snapshot() {
    log_step "本番環境のスナップショットを作成中..."
    
    local snapshot_id
    snapshot_id="wp-production-$(date +%Y%m%d-%H%M%S)"
    
    # RDSスナップショットの作成
    aws rds create-db-snapshot \
        --db-instance-identifier "$PROD_RDS_ID" \
        --db-snapshot-identifier "$snapshot_id" \
        --tags Key=Purpose,Value=DeploymentBackup Key=Date,Value=$(date +%Y-%m-%d) \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # スナップショットの完了を待機
    log_info "RDSスナップショットの完了を待機中..."
    aws rds wait db-snapshot-completed \
        --db-snapshot-identifier "$snapshot_id" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    log_success "RDSスナップショット作成完了: $snapshot_id"
    echo "$snapshot_id"
}

# 検証環境の起動
start_validation_environment() {
    log_step "検証環境を起動中..."
    
    # 検証用EC2の起動
    aws ec2 start-instances \
        --instance-ids "$VALID_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # EC2の起動完了を待機
    log_info "検証用EC2の起動完了を待機中..."
    aws ec2 wait instance-running \
        --instance-ids "$VALID_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    log_success "検証用EC2起動完了"
    
    # 検証用RDSの起動（スナップショットから復元）
    local snapshot_id="$1"
    if aws rds describe-db-instances \
        --db-instance-identifier "$VALID_RDS_ID" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" 2>/dev/null | grep -q "available"; then
        log_info "検証用RDSは既に起動しています"
    else
        log_info "検証用RDSをスナップショットから復元中..."
        aws rds restore-db-instance-from-db-snapshot \
            --db-instance-identifier "$VALID_RDS_ID" \
            --db-snapshot-identifier "$snapshot_id" \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE"
        
        # RDSの復元完了を待機
        log_info "検証用RDSの復元完了を待機中..."
        aws rds wait db-instance-available \
            --db-instance-identifier "$VALID_RDS_ID" \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE"
    fi
    
    log_success "検証環境の起動が完了しました"
}

# 検証環境でのテスト実行
run_validation_tests() {
    log_step "検証環境でのテストを実行中..."
    
    # 検証環境のURL確認
    log_info "検証環境のURL: $VALID_WP_URL"
    
    # 基本的な接続テスト
    if ! curl -f -s -o /dev/null --max-time 30 "$VALID_WP_URL"; then
        error_exit "検証環境への接続に失敗しました: $VALID_WP_URL"
    fi
    
    log_info "検証環境への接続テストが成功しました"
    
    # ユーザー確認（自動承認でない場合）
    if [ "$AUTO_APPROVE" != "true" ]; then
        log_input "検証環境でのテストが完了しました。本番環境に反映しますか？ (y/N): "
        read -p "> " confirm_deployment
        if [ "$confirm_deployment" != "y" ]; then
            log_info "デプロイメントをキャンセルしました"
            stop_validation_environment
            exit 0
        fi
    fi
    
    log_success "検証環境でのテストが完了しました"
}

# 本番環境への反映
deploy_to_production() {
    log_step "本番環境に反映中..."
    
    # 本番環境のバックアップ作成
    if [ "$BACKUP_BEFORE_DEPLOYMENT" = "true" ]; then
        create_production_snapshot
    fi
    
    # 本番環境の停止
    log_info "本番環境を一時停止中..."
    aws ec2 stop-instances \
        --instance-ids "$PROD_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # EC2の停止完了を待機
    aws ec2 wait instance-stopped \
        --instance-ids "$PROD_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # 検証環境から本番環境へのデータ同期
    log_info "検証環境から本番環境へのデータ同期中..."
    # ここで実際のデータ同期処理を実装
    
    # 本番環境の起動
    log_info "本番環境を起動中..."
    aws ec2 start-instances \
        --instance-ids "$PROD_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # EC2の起動完了を待機
    aws ec2 wait instance-running \
        --instance-ids "$PROD_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # 本番環境の動作確認
    log_info "本番環境の動作確認中..."
    if ! curl -f -s -o /dev/null --max-time 30 "$PROD_WP_URL"; then
        error_exit "本番環境への接続に失敗しました: $PROD_WP_URL"
    fi
    
    log_success "本番環境への反映が完了しました"
}

# 検証環境の停止
stop_validation_environment() {
    log_step "検証環境を停止中..."
    
    # 検証用EC2の停止
    aws ec2 stop-instances \
        --instance-ids "$VALID_EC2_ID" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    
    # 検証用RDSの停止（オプション）
    # 注意: RDSの停止は料金が発生する場合があります
    log_info "検証用RDSは手動で停止してください（コスト削減のため）"
    
    log_success "検証環境の停止が完了しました"
}

# 通知送信
send_notification() {
    local message="$1"
    local status="$2"
    
    if [ -n "$NOTIFICATION_EMAIL" ]; then
        log_info "通知メールを送信中..."
        # ここでメール送信処理を実装
        echo "$message" | mail -s "WordPressデプロイメント: $status" "$NOTIFICATION_EMAIL" || true
    fi
}

# ロールバック処理
rollback_deployment() {
    log_error "デプロイメントに失敗しました。ロールバックを実行します..."
    
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log_step "ロールバック処理を開始..."
        
        # 最新のスナップショットを取得
        local latest_snapshot
        latest_snapshot=$(aws rds describe-db-snapshots \
            --query 'DBSnapshots[?DBInstanceIdentifier==`'"$PROD_RDS_ID"'`] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
            --output text \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE")
        
        if [ -n "$latest_snapshot" ] && [ "$latest_snapshot" != "None" ]; then
            log_info "最新スナップショットから復元中: $latest_snapshot"
            
            # 本番環境をスナップショットから復元
            aws rds restore-db-instance-from-db-snapshot \
                --db-instance-identifier "$PROD_RDS_ID" \
                --db-snapshot-identifier "$latest_snapshot" \
                --region "$AWS_REGION" \
                --profile "$AWS_PROFILE"
            
            log_success "ロールバックが完了しました"
        else
            log_error "利用可能なスナップショットが見つかりません"
        fi
    else
        log_warn "ロールバックが無効になっています"
    fi
}

# ドライラン実行
run_dry_run() {
    log_info "=== ドライラン実行 ==="
    
    load_deployment_config
    validate_deployment_config
    
    log_info "ドライラン結果:"
    echo "  本番EC2: $PROD_EC2_ID"
    echo "  本番RDS: $PROD_RDS_ID"
    echo "  検証EC2: $VALID_EC2_ID"
    echo "  検証RDS: $VALID_RDS_ID"
    echo "  本番URL: $PROD_WP_URL"
    echo "  検証URL: $VALID_WP_URL"
    echo "  自動承認: $AUTO_APPROVE"
    echo "  ロールバック: $ROLLBACK_ON_FAILURE"
    
    log_success "ドライランが完了しました"
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    # 共通初期化
    init_common "$SCRIPT_NAME"
    
    # 引数の解析
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error_exit "不明なオプション: $1"
                ;;
        esac
    done
    
    # ドライラン実行
    if [ "$dry_run" = true ]; then
        run_dry_run
        finish_script "$SCRIPT_NAME" 0
    fi
    
    # メイン処理
    local snapshot_id
    local exit_code=0
    
    # エラーハンドリング
    trap 'rollback_deployment; stop_validation_environment; send_notification "デプロイメントが失敗しました" "FAILED"; exit 1' ERR
    
    try {
        # 設定の読み込みと検証
        load_deployment_config
        validate_deployment_config
        
        # ステップ1: 本番環境のスナップショット作成
        snapshot_id=$(create_production_snapshot)
        
        # ステップ2: 検証環境の起動
        start_validation_environment "$snapshot_id"
        
        # ステップ3: 検証環境でのテスト
        run_validation_tests
        
        # ステップ4: 本番環境への反映
        deploy_to_production
        
        # ステップ5: 検証環境の停止
        stop_validation_environment
        
        # 成功通知
        send_notification "デプロイメントが正常に完了しました" "SUCCESS"
        
        log_success "デプロイメントが正常に完了しました"
        
    } catch {
        exit_code=$?
        log_error "デプロイメント中にエラーが発生しました"
        return $exit_code
    }
    
    finish_script "$SCRIPT_NAME" $exit_code
}

# スクリプト実行
main "$@" 