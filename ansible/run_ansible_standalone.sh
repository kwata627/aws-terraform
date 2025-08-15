#!/bin/bash
# Ansible単独実行スクリプト（Terraform連携版）
# Terraformで設定された値を使用してAnsibleを実行

set -e

# =============================================================================
# 定数定義
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$SCRIPT_DIR"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"
LOG_FILE="$ANSIBLE_DIR/ansible_standalone_$(date +%Y%m%d_%H%M%S).log"

# =============================================================================
# 色付きログ関数
# =============================================================================

log_info() {
    echo -e "\033[32m[INFO]\033[0m $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "\033[36m[DEBUG]\033[0m $1" | tee -a "$LOG_FILE"
    fi
}

# =============================================================================
# ヘルプ表示
# =============================================================================

show_help() {
    cat << EOF
Ansible単独実行スクリプト（Terraform連携版）

使用方法:
    $0 [オプション] [プレイブック]

オプション:
    -h, --help              このヘルプを表示
    -v, --verbose           詳細ログを出力
    -d, --debug            デバッグモードを有効化
    -i, --inventory FILE   インベントリファイルを指定（デフォルト: inventory/hosts.yml）
    -e, --extra-vars VARS  追加変数を指定
    -t, --tags TAGS        実行するタグを指定
    --skip-tags TAGS       スキップするタグを指定
    --check                 ドライラン（実際の変更は行わない）
    --diff                  変更の差分を表示

プレイブック:
    wordpress-setup          WordPress環境構築（デフォルト）
    load-vars               Terraform変数の読み込みのみ
    ssl-setup               SSL証明書設定
    update-config           WordPress設定更新

例:
    $0 wordpress-setup
    $0 -v -e "wordpress_domain=example.com"
    $0 --check wordpress-setup
    $0 -t "apache,php" wordpress-setup

EOF
}

# =============================================================================
# 引数解析
# =============================================================================

PLAYBOOK="wordpress-setup"
VERBOSE=""
DEBUG=""
INVENTORY="$INVENTORY_FILE"
EXTRA_VARS=""
TAGS=""
SKIP_TAGS=""
CHECK=""
DIFF=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -d|--debug)
            DEBUG="true"
            VERBOSE="-vvv"
            shift
            ;;
        -i|--inventory)
            INVENTORY="$2"
            shift 2
            ;;
        -e|--extra-vars)
            EXTRA_VARS="$2"
            shift 2
            ;;
        -t|--tags)
            TAGS="--tags $2"
            shift 2
            ;;
        --skip-tags)
            SKIP_TAGS="--skip-tags $2"
            shift 2
            ;;
        --check)
            CHECK="--check"
            shift
            ;;
        --diff)
            DIFF="--diff"
            shift
            ;;
        wordpress-setup|load-vars|ssl-setup|update-config)
            PLAYBOOK="$1"
            shift
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# 初期化
# =============================================================================

log_info "Ansible単独実行を開始します"
log_info "作業ディレクトリ: $ANSIBLE_DIR"
log_info "Terraformディレクトリ: $TERRAFORM_DIR"
log_info "ログファイル: $LOG_FILE"

# 作業ディレクトリに移動
cd "$ANSIBLE_DIR"

# =============================================================================
# 前提条件チェック
# =============================================================================

log_info "前提条件をチェック中..."

# Ansibleの存在確認
if ! command -v ansible-playbook &> /dev/null; then
    log_error "ansible-playbookが見つかりません"
    exit 1
fi

# Python3の存在確認
if ! command -v python3 &> /dev/null; then
    log_error "python3が見つかりません"
    exit 1
fi

# 必要なPythonパッケージの確認
if ! python3 -c "import yaml" 2>/dev/null; then
    log_error "PyYAMLがインストールされていません: pip3 install PyYAML"
    exit 1
fi

log_info "前提条件チェック完了"

# =============================================================================
# Terraform状態の確認
# =============================================================================

log_info "Terraform状態を確認中..."

if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    log_info "Terraform stateファイルが見つかりました"
    TERRAFORM_AVAILABLE=true
else
    log_warn "Terraform stateファイルが見つかりません"
    log_warn "デフォルト値を使用してAnsibleを実行します"
    TERRAFORM_AVAILABLE=false
fi

# =============================================================================
# インベントリ生成
# =============================================================================

if [ "$TERRAFORM_AVAILABLE" = true ]; then
    log_info "インベントリを生成中..."
    
    if python3 generate_inventory.py; then
        log_info "インベントリ生成完了"
    else
        log_warn "インベントリ生成に失敗しました"
        log_warn "テンプレートインベントリを使用します"
        
        # テンプレートインベントリの作成
        mkdir -p inventory
        cat > "$INVENTORY_FILE" << EOF
all:
  children:
    wordpress:
      hosts:
        wordpress_ec2:
          ansible_host: "{{ lookup('env', 'WORDPRESS_PUBLIC_IP', default='localhost') }}"
          ansible_user: "{{ lookup('env', 'SSH_USER', default='ec2-user') }}"
          ansible_ssh_private_key_file: "{{ lookup('env', 'SSH_PRIVATE_KEY_FILE', default='~/.ssh/ssh_key') }}"
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF
        log_info "テンプレートインベントリを作成しました"
    fi
else
    log_info "テンプレートインベントリを作成中..."
    
    mkdir -p inventory
    cat > "$INVENTORY_FILE" << EOF
all:
  children:
    wordpress:
      hosts:
        wordpress_ec2:
          ansible_host: "{{ lookup('env', 'WORDPRESS_PUBLIC_IP', default='localhost') }}"
          ansible_user: "{{ lookup('env', 'SSH_USER', default='ec2-user') }}"
          ansible_ssh_private_key_file: "{{ lookup('env', 'SSH_PRIVATE_KEY_FILE', default='~/.ssh/ssh_key') }}"
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF
    log_info "テンプレートインベントリを作成しました"
fi

# =============================================================================
# プレイブックの選択
# =============================================================================

case "$PLAYBOOK" in
    wordpress-setup)
        PLAYBOOK_FILE="playbooks/wordpress_setup.yml"
        log_info "WordPress環境構築を実行します"
        ;;
    load-vars)
        PLAYBOOK_FILE="playbooks/load_terraform_vars.yml"
        log_info "Terraform変数の読み込みを実行します"
        ;;
    ssl-setup)
        PLAYBOOK_FILE="playbooks/lets_encrypt_setup.yml"
        log_info "SSL証明書設定を実行します"
        ;;
    update-config)
        PLAYBOOK_FILE="playbooks/update_wordpress_config.yml"
        log_info "WordPress設定更新を実行します"
        ;;
    *)
        log_error "不明なプレイブック: $PLAYBOOK"
        exit 1
        ;;
esac

# =============================================================================
# Ansible実行
# =============================================================================

log_info "Ansibleプレイブックを実行中..."
log_info "プレイブック: $PLAYBOOK_FILE"
log_info "インベントリ: $INVENTORY"

# コマンドの構築
ANSIBLE_CMD="ansible-playbook"
ANSIBLE_CMD="$ANSIBLE_CMD -i $INVENTORY"
ANSIBLE_CMD="$ANSIBLE_CMD $PLAYBOOK_FILE"

if [ -n "$VERBOSE" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $VERBOSE"
fi

if [ -n "$EXTRA_VARS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e \"$EXTRA_VARS\""
fi

if [ -n "$TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $TAGS"
fi

if [ -n "$SKIP_TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $SKIP_TAGS"
fi

if [ -n "$CHECK" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $CHECK"
fi

if [ -n "$DIFF" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $DIFF"
fi

log_debug "実行コマンド: $ANSIBLE_CMD"

# Ansible実行
if eval "$ANSIBLE_CMD"; then
    log_info "Ansibleプレイブックの実行が完了しました"
else
    log_error "Ansibleプレイブックの実行に失敗しました"
    exit 1
fi

# =============================================================================
# 完了
# =============================================================================

log_info "Ansible単独実行が完了しました"
log_info "ログファイル: $LOG_FILE"

exit 0
