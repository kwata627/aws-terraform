#!/bin/bash

# =============================================================================
# Ansible環境 共通ライブラリ
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
readonly DEFAULT_INVENTORY_FILE="inventory/hosts.yml"
readonly DEFAULT_LOG_FILE="ansible_$(date +%Y%m%d_%H%M%S).log"
readonly DEFAULT_ANSIBLE_CONFIG="ansible.cfg"

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
# Ansible関連関数
# =============================================================================

# Ansibleの確認
check_ansible() {
    if ! command -v ansible >/dev/null 2>&1; then
        error_exit "Ansibleがインストールされていません"
    fi
    
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        error_exit "ansible-playbookが利用できません"
    fi
    
    log_info "Ansibleを確認しました"
}

# インベントリファイルの確認
check_inventory() {
    local inventory_file="${1:-$DEFAULT_INVENTORY_FILE}"
    
    if [ ! -f "$inventory_file" ]; then
        error_exit "インベントリファイルが見つかりません: $inventory_file"
    fi
    
    log_info "インベントリファイルを確認しました: $inventory_file"
}

# プレイブックファイルの確認
check_playbook() {
    local playbook_file="$1"
    
    if [ ! -f "$playbook_file" ]; then
        error_exit "プレイブックファイルが見つかりません: $playbook_file"
    fi
    
    log_info "プレイブックファイルを確認しました: $playbook_file"
}

# Ansible設定ファイルの確認
check_ansible_config() {
    local config_file="${1:-$DEFAULT_ANSIBLE_CONFIG}"
    
    if [ ! -f "$config_file" ]; then
        error_exit "Ansible設定ファイルが見つかりません: $config_file"
    fi
    
    log_info "Ansible設定ファイルを確認しました: $config_file"
}

# 接続テスト
test_connection() {
    local inventory_file="${1:-$DEFAULT_INVENTORY_FILE}"
    local group="${2:-all}"
    
    log_step "接続テストを実行中..."
    
    if ansible -i "$inventory_file" "$group" -m ping; then
        log_success "接続テストが成功しました"
        return 0
    else
        error_exit "接続テストに失敗しました"
    fi
}

# 構文チェック
check_syntax() {
    local playbook_file="$1"
    
    log_step "構文チェックを実行中..."
    
    if ansible-playbook --syntax-check "$playbook_file"; then
        log_success "構文チェックが成功しました"
        return 0
    else
        error_exit "構文チェックに失敗しました"
    fi
}

# ドライラン実行
run_dry_run() {
    local playbook_file="$1"
    local inventory_file="${2:-$DEFAULT_INVENTORY_FILE}"
    
    log_step "ドライランを実行中..."
    
    if ansible-playbook -i "$inventory_file" --check --diff "$playbook_file"; then
        log_success "ドライランが完了しました"
        return 0
    else
        error_exit "ドライランに失敗しました"
    fi
}

# プレイブック実行
run_playbook() {
    local playbook_file="$1"
    local inventory_file="${2:-$DEFAULT_INVENTORY_FILE}"
    local extra_vars="${3:-}"
    local tags="${4:-}"
    
    log_step "プレイブックを実行中: $playbook_file"
    
    local cmd="ansible-playbook -i '$inventory_file' '$playbook_file'"
    
    if [ -n "$extra_vars" ]; then
        cmd="$cmd --extra-vars '$extra_vars'"
    fi
    
    if [ -n "$tags" ]; then
        cmd="$cmd --tags '$tags'"
    fi
    
    if eval "$cmd"; then
        log_success "プレイブックの実行が完了しました"
        return 0
    else
        error_exit "プレイブックの実行に失敗しました"
    fi
}

# =============================================================================
# Terraform連携関数
# =============================================================================

# Terraform出力の取得
get_terraform_output() {
    log_step "Terraform出力を取得中..."
    
    if ! command -v terraform >/dev/null 2>&1; then
        error_exit "Terraformがインストールされていません"
    fi
    
    # 親ディレクトリに移動してTerraform出力を取得
    local current_dir
    current_dir=$(pwd)
    cd ..
    
    if terraform output -json >/dev/null 2>&1; then
        local output
        output=$(terraform output -json)
        cd "$current_dir"
        echo "$output"
    else
        cd "$current_dir"
        error_exit "Terraform出力の取得に失敗しました"
    fi
}

# インベントリ生成スクリプトの実行
generate_inventory() {
    log_step "インベントリを生成中..."
    
    if [ -f "generate_inventory.py" ]; then
        if python3 generate_inventory.py; then
            log_success "インベントリの生成が完了しました"
            return 0
        else
            error_exit "インベントリの生成に失敗しました"
        fi
    else
        error_exit "generate_inventory.pyが見つかりません"
    fi
}

# =============================================================================
# 設定管理関数
# =============================================================================

# 環境変数の確認
check_environment_vars() {
    local required_vars=("$@")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_warn "環境変数が設定されていません: $var"
        else
            log_info "環境変数を確認しました: $var"
        fi
    done
}

# 設定ファイルの検証
validate_config_file() {
    local config_file="$1"
    local config_type="${2:-yaml}"
    
    if [ ! -f "$config_file" ]; then
        error_exit "設定ファイルが見つかりません: $config_file"
    fi
    
    case "$config_type" in
        "yaml"|"yml")
            if command -v python3 >/dev/null 2>&1; then
                if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
                    log_info "YAML設定ファイルを検証しました: $config_file"
                else
                    error_exit "YAML設定ファイルの形式が無効です: $config_file"
                fi
            else
                log_warn "Python3が利用できません。YAML検証をスキップします"
            fi
            ;;
        "json")
            if command -v jq >/dev/null 2>&1; then
                if jq empty "$config_file" 2>/dev/null; then
                    log_info "JSON設定ファイルを検証しました: $config_file"
                else
                    error_exit "JSON設定ファイルの形式が無効です: $config_file"
                fi
            else
                log_warn "jqが利用できません。JSON検証をスキップします"
            fi
            ;;
        *)
            log_info "設定ファイルを確認しました: $config_file"
            ;;
    esac
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
    local retention_days="${2:-7}"
    
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
init_ansible_common() {
    local script_name="$1"
    
    log_info "=== $script_name 開始 ==="
    
    # 必要なコマンドの確認
    check_required_commands "ansible" "ansible-playbook"
    
    # Ansible設定の確認
    check_ansible_config
    
    # ログファイルの初期化
    LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
    touch "$LOG_FILE"
    
    log_info "Ansible共通初期化が完了しました"
}

# スクリプト終了処理
finish_ansible_script() {
    local script_name="$1"
    local exit_code="${2:-0}"
    
    if [ $exit_code -eq 0 ]; then
        log_success "=== $script_name 正常終了 ==="
    else
        log_error "=== $script_name 異常終了 (終了コード: $exit_code) ==="
    fi
    
    exit $exit_code
} 