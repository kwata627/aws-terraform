#!/bin/bash

# =============================================================================
# GitHub Actions WordPress Deployment Helper
# =============================================================================

set -euo pipefail

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="GitHub Actions Deployment Helper"
readonly CONFIG_FILE="deployment_config.json"
readonly LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

# 色コード
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# ログ関数
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# 設定管理
# =============================================================================

# 設定ファイルの検証
validate_config_file() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [ ! -f "$config_file" ]; then
        log_error "設定ファイルが見つかりません: $config_file"
        return 1
    fi
    
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "設定ファイルのJSON形式が無効です: $config_file"
        return 1
    fi
    
    log_info "設定ファイルを検証しました: $config_file"
    return 0
}

# 設定値の読み込み
load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    local key="$2"
    local default_value="${3:-}"
    
    if ! validate_config_file "$config_file"; then
        return 1
    fi
    
    local value
    value=$(jq -r "$key" "$config_file" 2>/dev/null)
    
    if [ "$value" = "null" ] || [ "$value" = "" ]; then
        if [ -n "$default_value" ]; then
            log_warn "設定値が見つかりません: $key (デフォルト値を使用: $default_value)"
            echo "$default_value"
        else
            log_error "必須設定値が見つかりません: $key"
            return 1
        fi
    else
        echo "$value"
    fi
}

# =============================================================================
# AWS関連関数
# =============================================================================

# AWS認証情報の確認
check_aws_credentials() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS認証情報が設定されていません"
        return 1
    fi
    
    local account_id
    account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    log_info "AWS認証情報を確認しました (Account: $account_id)"
    return 0
}

# AWSリソースの存在確認
check_aws_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local region="${3:-ap-northeast-1}"
    
    case "$resource_type" in
        "ec2")
            if ! aws ec2 describe-instances --instance-ids "$resource_id" --query 'Reservations[0].Instances[0].InstanceId' --output text --region "$region" >/dev/null 2>&1; then
                log_error "EC2インスタンスが見つかりません: $resource_id"
                return 1
            fi
            ;;
        "rds")
            if ! aws rds describe-db-instances --db-instance-identifier "$resource_id" --query 'DBInstances[0].DBInstanceIdentifier' --output text --region "$region" >/dev/null 2>&1; then
                log_error "RDSインスタンスが見つかりません: $resource_id"
                return 1
            fi
            ;;
        *)
            log_error "未対応のリソースタイプです: $resource_type"
            return 1
            ;;
    esac
    
    log_info "AWSリソースを確認しました: $resource_type/$resource_id"
    return 0
}

# =============================================================================
# デプロイメント関数
# =============================================================================

# 本番環境のスナップショット作成
create_production_snapshot() {
    local prod_rds_id="$1"
    local region="${2:-ap-northeast-1}"
    
    log_step "本番環境のスナップショットを作成中..."
    
    local snapshot_id
    snapshot_id="wp-production-$(date +%Y%m%d-%H%M%S)"
    
    # RDSスナップショットの作成
    aws rds create-db-snapshot \
        --db-instance-identifier "$prod_rds_id" \
        --db-snapshot-identifier "$snapshot_id" \
        --tags Key=Purpose,Value=DeploymentBackup Key=Date,Value=$(date +%Y-%m-%d) \
        --region "$region"
    
    # スナップショットの完了を待機
    log_info "RDSスナップショットの完了を待機中..."
    aws rds wait db-snapshot-completed \
        --db-snapshot-identifier "$snapshot_id" \
        --region "$region"
    
    log_success "RDSスナップショット作成完了: $snapshot_id"
    echo "$snapshot_id"
}

# 検証環境の起動
start_validation_environment() {
    local valid_ec2_id="$1"
    local valid_rds_id="$2"
    local snapshot_id="$3"
    local region="${4:-ap-northeast-1}"
    
    log_step "検証環境を起動中..."
    
    # 検証用EC2の起動
    aws ec2 start-instances \
        --instance-ids "$valid_ec2_id" \
        --region "$region"
    
    # EC2の起動完了を待機
    log_info "検証用EC2の起動完了を待機中..."
    aws ec2 wait instance-running \
        --instance-ids "$valid_ec2_id" \
        --region "$region"
    
    log_success "検証用EC2起動完了"
    
    # 検証用RDSの起動（スナップショットから復元）
    if ! aws rds describe-db-instances \
        --db-instance-identifier "$valid_rds_id" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text \
        --region "$region" 2>/dev/null | grep -q "available"; then
        log_info "検証用RDSをスナップショットから復元中..."
        aws rds restore-db-instance-from-db-snapshot \
            --db-instance-identifier "$valid_rds_id" \
            --db-snapshot-identifier "$snapshot_id" \
            --region "$region"
        
        # RDSの復元完了を待機
        log_info "検証用RDSの復元完了を待機中..."
        aws rds wait db-instance-available \
            --db-instance-identifier "$valid_rds_id" \
            --region "$region"
    else
        log_info "検証用RDSは既に起動しています"
    fi
    
    log_success "検証環境の起動が完了しました"
}

# 検証環境でのテスト実行
run_validation_tests() {
    local valid_wp_url="$1"
    local test_timeout="${2:-30}"
    
    log_step "検証環境でのテストを実行中..."
    
    # 検証環境のURL確認
    log_info "検証環境のURL: $valid_wp_url"
    
    # 基本的な接続テスト
    local max_attempts=$((test_timeout * 6))  # 10秒間隔でテスト
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s -o /dev/null --max-time 30 "$valid_wp_url"; then
            log_info "検証環境への接続テストが成功しました"
            log_success "検証環境でのテストが完了しました"
            return 0
        else
            log_info "Attempt $attempt/$max_attempts: 検証環境への接続に失敗しました。10秒後に再試行..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    log_error "検証環境への接続に失敗しました: $valid_wp_url"
    return 1
}

# 本番環境への反映
deploy_to_production() {
    local prod_ec2_id="$1"
    local prod_wp_url="$2"
    local region="${3:-ap-northeast-1}"
    
    log_step "本番環境に反映中..."
    
    # 本番環境の停止
    log_info "本番環境を一時停止中..."
    aws ec2 stop-instances \
        --instance-ids "$prod_ec2_id" \
        --region "$region"
    
    # EC2の停止完了を待機
    aws ec2 wait instance-stopped \
        --instance-ids "$prod_ec2_id" \
        --region "$region"
    
    # 検証環境から本番環境へのデータ同期
    log_info "検証環境から本番環境へのデータ同期中..."
    # ここで実際のデータ同期処理を実装
    
    # 本番環境の起動
    log_info "本番環境を起動中..."
    aws ec2 start-instances \
        --instance-ids "$prod_ec2_id" \
        --region "$region"
    
    # EC2の起動完了を待機
    aws ec2 wait instance-running \
        --instance-ids "$prod_ec2_id" \
        --region "$region"
    
    # 本番環境の動作確認
    log_info "本番環境の動作確認中..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s -o /dev/null --max-time 30 "$prod_wp_url"; then
            log_success "本番環境への反映が完了しました"
            return 0
        else
            log_info "Attempt $attempt/$max_attempts: 本番環境への接続に失敗しました。10秒後に再試行..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    log_error "本番環境への接続に失敗しました: $prod_wp_url"
    return 1
}

# 検証環境の停止
stop_validation_environment() {
    local valid_ec2_id="$1"
    local region="${2:-ap-northeast-1}"
    
    log_step "検証環境を停止中..."
    
    # 検証用EC2の停止
    aws ec2 stop-instances \
        --instance-ids "$valid_ec2_id" \
        --region "$region"
    
    log_success "検証環境の停止が完了しました"
}

# ロールバック処理
rollback_deployment() {
    local prod_rds_id="$1"
    local region="${2:-ap-northeast-1}"
    
    log_error "デプロイメントに失敗しました。ロールバックを実行します..."
    
    # 最新のスナップショットを取得
    local latest_snapshot
    latest_snapshot=$(aws rds describe-db-snapshots \
        --query 'DBSnapshots[?DBInstanceIdentifier==`'"$prod_rds_id"'`] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
        --output text \
        --region "$region")
    
    if [ -n "$latest_snapshot" ] && [ "$latest_snapshot" != "None" ]; then
        log_info "最新スナップショットから復元中: $latest_snapshot"
        
        # 本番環境をスナップショットから復元
        aws rds restore-db-instance-from-db-snapshot \
            --db-instance-identifier "$prod_rds_id" \
            --db-snapshot-identifier "$latest_snapshot" \
            --region "$region"
        
        log_success "ロールバックが完了しました"
    else
        log_error "利用可能なスナップショットが見つかりません"
        return 1
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_info "=== $SCRIPT_NAME 開始 ==="
    
    # 必要なコマンドの確認
    local required_commands=("jq" "aws" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "必要なコマンドが見つかりません: $cmd"
            exit 1
        fi
    done
    
    # AWS認証情報の確認
    if ! check_aws_credentials; then
        exit 1
    fi
    
    # 設定ファイルの確認
    if ! validate_config_file; then
        exit 1
    fi
    
    log_info "初期化が完了しました"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 