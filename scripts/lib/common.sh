#!/bin/bash

# =============================================================================
# WordPress AWS環境 共通ライブラリ
# =============================================================================

# エラー時に停止
set -euo pipefail

# =============================================================================
# 定数定義
# =============================================================================

# 色コード
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ログレベル
readonly LOG_LEVEL_INFO=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_ERROR=2

# デフォルト設定
readonly DEFAULT_CONFIG_FILE="deployment_config.json"
readonly DEFAULT_LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"
readonly DEFAULT_BACKUP_RETENTION_DAYS=7
readonly DEFAULT_TEST_TIMEOUT_MINUTES=30

# =============================================================================
# ログ関数
# =============================================================================

# ログレベル設定（環境変数から取得、デフォルトはINFO）
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

log_info() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]; then
        echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE:-$DEFAULT_LOG_FILE}"
    fi
}

log_warn() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_WARN" ]; then
        echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE:-$DEFAULT_LOG_FILE}"
    fi
}

log_error() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]; then
        echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE:-$DEFAULT_LOG_FILE}"
    fi
}

log_input() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE:-$DEFAULT_LOG_FILE}"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE:-$DEFAULT_LOG_FILE}"
}

# =============================================================================
# エラーハンドリング
# =============================================================================

# エラー終了関数
error_exit() {
    log_error "$1"
    exit 1
}

# 警告関数
warn_exit() {
    log_warn "$1"
    exit 1
}

# クリーンアップ関数
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "スクリプトが異常終了しました (終了コード: $exit_code)"
    fi
    exit $exit_code
}

# トラップ設定
trap cleanup EXIT

# =============================================================================
# 設定管理
# =============================================================================

# 設定ファイルの検証
validate_config_file() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    
    if [ ! -f "$config_file" ]; then
        error_exit "設定ファイルが見つかりません: $config_file"
    fi
    
    if ! jq empty "$config_file" 2>/dev/null; then
        error_exit "設定ファイルのJSON形式が無効です: $config_file"
    fi
    
    log_info "設定ファイルを検証しました: $config_file"
}

# 設定値の読み込み
load_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    local key="$2"
    local default_value="${3:-}"
    
    validate_config_file "$config_file"
    
    local value
    value=$(jq -r "$key" "$config_file" 2>/dev/null)
    
    if [ "$value" = "null" ] || [ "$value" = "" ]; then
        if [ -n "$default_value" ]; then
            log_warn "設定値が見つかりません: $key (デフォルト値を使用: $default_value)"
            echo "$default_value"
        else
            error_exit "必須設定値が見つかりません: $key"
        fi
    else
        echo "$value"
    fi
}

# 設定値の更新
update_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    local key="$2"
    local value="$3"
    
    validate_config_file "$config_file"
    
    # 一時ファイルに書き込み
    local temp_file
    temp_file=$(mktemp)
    
    jq "$key = \"$value\"" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    log_info "設定を更新しました: $key = $value"
}

# =============================================================================
# AWS関連関数
# =============================================================================

# AWS認証情報の確認
check_aws_credentials() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error_exit "AWS認証情報が設定されていません。aws configure を実行してください。"
    fi
    
    local account_id
    account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    log_info "AWS認証情報を確認しました (Account: $account_id)"
}

# AWSリソースの存在確認
check_aws_resource() {
    local resource_type="$1"
    local resource_id="$2"
    
    case "$resource_type" in
        "ec2")
            if ! aws ec2 describe-instances --instance-ids "$resource_id" --query 'Reservations[0].Instances[0].InstanceId' --output text >/dev/null 2>&1; then
                error_exit "EC2インスタンスが見つかりません: $resource_id"
            fi
            ;;
        "rds")
            if ! aws rds describe-db-instances --db-instance-identifier "$resource_id" --query 'DBInstances[0].DBInstanceIdentifier' --output text >/dev/null 2>&1; then
                error_exit "RDSインスタンスが見つかりません: $resource_id"
            fi
            ;;
        *)
            error_exit "未対応のリソースタイプです: $resource_type"
            ;;
    esac
    
    log_info "AWSリソースを確認しました: $resource_type/$resource_id"
}

# =============================================================================
# ユーティリティ関数
# =============================================================================

# 必須コマンドの確認
check_required_commands() {
    local commands=("$@")
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "必要なコマンドが見つかりません: $cmd"
        fi
    done
    
    log_info "必要なコマンドを確認しました: ${commands[*]}"
}

# ファイルの存在確認
check_file_exists() {
    local file="$1"
    local description="${2:-ファイル}"
    
    if [ ! -f "$file" ]; then
        error_exit "$description が見つかりません: $file"
    fi
    
    log_info "$description を確認しました: $file"
}

# ディレクトリの存在確認
check_directory_exists() {
    local dir="$1"
    local description="${2:-ディレクトリ}"
    
    if [ ! -d "$dir" ]; then
        error_exit "$description が見つかりません: $dir"
    fi
    
    log_info "$description を確認しました: $dir"
}

# 権限確認
check_permissions() {
    local file="$1"
    local required_perms="$2"
    
    if [ ! -r "$file" ]; then
        error_exit "ファイルの読み取り権限がありません: $file"
    fi
    
    if [ "$required_perms" = "executable" ] && [ ! -x "$file" ]; then
        error_exit "ファイルの実行権限がありません: $file"
    fi
    
    log_info "ファイル権限を確認しました: $file"
}

# バックアップ作成
create_backup() {
    local source="$1"
    local backup_dir="${2:-./backups}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    if [ -f "$source" ]; then
        cp "$source" "$backup_dir/$(basename "$source").$timestamp"
        log_info "ファイルのバックアップを作成しました: $source -> $backup_dir/$(basename "$source").$timestamp"
    elif [ -d "$source" ]; then
        tar -czf "$backup_dir/$(basename "$source").$timestamp.tar.gz" -C "$(dirname "$source")" "$(basename "$source")"
        log_info "ディレクトリのバックアップを作成しました: $source -> $backup_dir/$(basename "$source").$timestamp.tar.gz"
    else
        error_exit "バックアップ対象が見つかりません: $source"
    fi
}

# 古いバックアップの削除
cleanup_old_backups() {
    local backup_dir="$1"
    local retention_days="${2:-$DEFAULT_BACKUP_RETENTION_DAYS}"
    
    if [ -d "$backup_dir" ]; then
        find "$backup_dir" -name "*.backup" -mtime +"$retention_days" -delete 2>/dev/null || true
        find "$backup_dir" -name "*.tar.gz" -mtime +"$retention_days" -delete 2>/dev/null || true
        log_info "古いバックアップを削除しました (保持期間: ${retention_days}日)"
    fi
}

# =============================================================================
# 初期化関数
# =============================================================================

# 共通初期化
init_common() {
    local script_name="$1"
    
    log_info "=== $script_name 開始 ==="
    
    # 必要なコマンドの確認
    check_required_commands "jq" "aws" "terraform"
    
    # AWS認証情報の確認
    check_aws_credentials
    
    # ログファイルの初期化
    LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
    touch "$LOG_FILE"
    
    log_info "共通初期化が完了しました"
}

# スクリプト終了処理
finish_script() {
    local script_name="$1"
    local exit_code="${2:-0}"
    
    if [ $exit_code -eq 0 ]; then
        log_success "=== $script_name 正常終了 ==="
    else
        log_error "=== $script_name 異常終了 (終了コード: $exit_code) ==="
    fi
    
    exit $exit_code
} 