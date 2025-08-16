#!/bin/bash

# =============================================================================
# Ansible単体実行スクリプト
# =============================================================================
# 
# terraform.tfvarsを直接読み込んでAnsibleを単体実行するスクリプト
# Terraform出力が取得できない環境でも実行可能
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# 環境変数の読み込み
source "$SCRIPT_DIR/load_env.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="Ansible単体実行"
readonly DEFAULT_PLAYBOOK="playbooks/wordpress_setup.yml"
readonly DEFAULT_INVENTORY="inventory/hosts.yml"
readonly DEFAULT_ENVIRONMENT="production"
readonly DEFAULT_TERRAFORM_TFVARS="../terraform.tfvars"
readonly DEFAULT_DEPLOYMENT_CONFIG="../deployment_config.json"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
Ansible単体実行スクリプト

terraform.tfvarsを直接読み込んでAnsibleを単体実行します。
Terraform出力が取得できない環境でも実行可能です。

使用方法:
  $0                                    # デフォルト設定で実行
  $0 --playbook <PLAYBOOK>              # 指定したプレイブックで実行
  $0 --environment <ENVIRONMENT>         # 指定した環境で実行
  $0 --dry-run                          # ドライラン実行
  $0 --step-by-step                     # 段階的実行
  $0 --help                            # このヘルプを表示

機能:
- terraform.tfvars直接読み込み
- deployment_config.json読み込み
- インベントリの自動生成
- 接続テスト
- 構文チェック
- プレイブック実行
- 環境別設定

環境変数:
- ENVIRONMENT: 環境名 (production/development)
- PLAYBOOK: プレイブックファイル
- DRY_RUN: ドライラン実行 (true/false)
- VERBOSE: 詳細出力 (true/false)
- LOG_LEVEL: ログレベル (INFO/WARN/ERROR)
- TERRAFORM_TFVARS: terraform.tfvarsファイルパス
- DEPLOYMENT_CONFIG: deployment_config.jsonファイルパス

例:
  $0 --environment production
  $0 --playbook playbooks/step_by_step_setup.yml --dry-run
  ENVIRONMENT=development $0

EOF
}

# 設定ファイルの検証
validate_config_files() {
    log_step "設定ファイルを検証中..."
    
    local terraform_tfvars="${TERRAFORM_TFVARS:-$DEFAULT_TERRAFORM_TFVARS}"
    local deployment_config="${DEPLOYMENT_CONFIG:-$DEFAULT_DEPLOYMENT_CONFIG}"
    
    # terraform.tfvarsの確認
    if [ -f "$terraform_tfvars" ]; then
        log_info "terraform.tfvarsファイルを確認しました: $terraform_tfvars"
        
        # 基本的な設定値の確認
        if grep -q "project" "$terraform_tfvars" && grep -q "domain_name" "$terraform_tfvars"; then
            log_info "terraform.tfvarsの基本設定を確認しました"
        else
            log_warn "terraform.tfvarsに必要な設定が不足している可能性があります"
        fi
    else
        log_error "terraform.tfvarsファイルが見つかりません: $terraform_tfvars"
        log_error "このスクリプトはterraform.tfvarsファイルが必要です"
        return 1
    fi
    
    # deployment_config.jsonの確認
    if [ -f "$deployment_config" ]; then
        if validate_config_file "$deployment_config" "json"; then
            log_info "deployment_config.jsonファイルを確認しました: $deployment_config"
        else
            log_warn "deployment_config.jsonの形式が無効です"
        fi
    else
        log_warn "deployment_config.jsonファイルが見つかりません: $deployment_config"
        log_info "terraform.tfvarsのみを使用して実行します"
    fi
    
    log_success "設定ファイルの検証が完了しました"
    return 0
}

# 環境変数の設定
setup_environment() {
    local environment="${1:-$DEFAULT_ENVIRONMENT}"
    
    log_step "環境設定を読み込み中: $environment"
    
    # 環境設定ファイルの確認
    local env_file="environments/${environment}.yml"
    if [ -f "$env_file" ]; then
        validate_config_file "$env_file" "yaml"
        log_info "環境設定ファイルを読み込みました: $env_file"
    else
        log_warn "環境設定ファイルが見つかりません: $env_file"
    fi
    
    # 環境変数の設定
    export ENVIRONMENT="$environment"
    export ANSIBLE_ENVIRONMENT="$environment"
    export STANDALONE_MODE="true"
    
    log_success "環境設定が完了しました: $environment"
}

# インベントリの準備
prepare_inventory() {
    log_step "インベントリを準備中..."
    
    # インベントリディレクトリの確認
    check_directory_exists "inventory" "インベントリディレクトリ"
    
    # 単体実行モードでインベントリ生成
    log_info "terraform.tfvarsからインベントリを生成中..."
    export STANDALONE_MODE="true"
    
    if [ -f "generate_inventory.py" ]; then
        python3 generate_inventory.py
        if [ $? -eq 0 ]; then
            log_success "インベントリの生成が完了しました"
        else
            log_error "インベントリの生成に失敗しました"
            return 1
        fi
    else
        log_error "generate_inventory.pyが見つかりません"
        return 1
    fi
    
    # 生成されたインベントリファイルの確認
    check_inventory "$DEFAULT_INVENTORY"
    
    log_success "インベントリの準備が完了しました"
}

# 変数ファイルの準備
prepare_variables() {
    log_step "Ansible変数を準備中..."
    
    log_info "terraform.tfvarsからAnsible変数を生成中..."
    export STANDALONE_MODE="true"
    
    # 変数生成スクリプトの実行
    if [ -f "scripts/load_terraform_vars.py" ]; then
        python3 scripts/load_terraform_vars.py
        if [ $? -eq 0 ]; then
            log_success "Ansible変数の生成が完了しました"
        else
            log_warn "Ansible変数の生成に失敗しましたが、処理を続行します"
        fi
    else
        log_warn "load_terraform_vars.pyが見つかりません"
    fi
}

# インベントリの確認
check_inventory() {
    local inventory_file="$1"
    
    if [ ! -f "$inventory_file" ]; then
        log_error "インベントリファイルが見つかりません: $inventory_file"
        return 1
    fi
    
    log_info "インベントリファイルを確認しました: $inventory_file"
    
    # インベントリの内容を表示
    if command -v ansible-inventory >/dev/null 2>&1; then
        log_info "インベントリの内容:"
        ansible-inventory --list -i "$inventory_file" 2>/dev/null | head -20
    fi
    
    return 0
}

# 接続テスト
test_connections() {
    log_step "接続テストを実行中..."
    
    local inventory_file="${1:-$DEFAULT_INVENTORY}"
    local timeout="${2:-30}"
    
    if [ ! -f "$inventory_file" ]; then
        log_error "インベントリファイルが見つかりません: $inventory_file"
        return 1
    fi
    
    # 接続テストの実行
    if command -v ansible >/dev/null 2>&1; then
        log_info "Ansible接続テストを実行中..."
        
        # 全ホストへのpingテスト
        if ansible all -i "$inventory_file" -m ping --timeout="$timeout" 2>/dev/null; then
            log_success "接続テストが完了しました"
        else
            log_warn "接続テストで一部のホストに接続できませんでした"
            log_info "IPアドレスが正しく設定されているか確認してください"
            return 1
        fi
    else
        log_warn "ansibleコマンドが見つかりません。接続テストをスキップします"
    fi
    
    return 0
}

# プレイブック実行
run_playbook() {
    local playbook="$1"
    local inventory_file="$2"
    local dry_run="$3"
    local step_by_step="$4"
    
    log_step "プレイブックを実行中: $playbook"
    
    if [ ! -f "$playbook" ]; then
        log_error "プレイブックファイルが見つかりません: $playbook"
        return 1
    fi
    
    if [ ! -f "$inventory_file" ]; then
        log_error "インベントリファイルが見つかりません: $inventory_file"
        return 1
    fi
    
    # Ansibleコマンドの構築
    local ansible_cmd="ansible-playbook"
    local args=(
        "-i" "$inventory_file"
        "$playbook"
    )
    
    # ドライランモード
    if [ "$dry_run" = "true" ]; then
        args+=("--check" "--diff")
        log_info "ドライランモードで実行します"
    fi
    
    # 段階的実行
    if [ "$step_by_step" = "true" ]; then
        args+=("--step")
        log_info "段階的実行モードで実行します"
    fi
    
    # 詳細出力
    if [ "${VERBOSE:-false}" = "true" ]; then
        args+=("-v")
    fi
    
    # プレイブックの実行
    log_info "Ansibleコマンド: $ansible_cmd ${args[*]}"
    
    if $ansible_cmd "${args[@]}"; then
        log_success "プレイブックの実行が完了しました"
        return 0
    else
        log_error "プレイブックの実行に失敗しました"
        return 1
    fi
}

# 環境テスト
test_environment() {
    log_step "環境テストを実行中..."
    
    local inventory_file="${1:-$DEFAULT_INVENTORY}"
    
    if [ -f "scripts/test_environment.sh" ]; then
        chmod +x scripts/test_environment.sh
        if ./scripts/test_environment.sh -i "$inventory_file"; then
            log_success "環境テストが完了しました"
        else
            log_warn "環境テストで警告が発生しました"
        fi
    else
        log_warn "test_environment.shが見つかりません。環境テストをスキップします"
    fi
}

# 設定情報の表示
show_config_info() {
    log_step "設定情報を表示中..."
    
    local terraform_tfvars="${TERRAFORM_TFVARS:-$DEFAULT_TERRAFORM_TFVARS}"
    local deployment_config="${DEPLOYMENT_CONFIG:-$DEFAULT_DEPLOYMENT_CONFIG}"
    
    echo ""
    echo "=== 設定情報 ==="
    echo "terraform.tfvars: $terraform_tfvars"
    echo "deployment_config.json: $deployment_config"
    echo "実行モード: 単体実行（terraform.tfvars直接読み込み）"
    echo ""
    
    # terraform.tfvarsの主要設定を表示
    if [ -f "$terraform_tfvars" ]; then
        echo "terraform.tfvarsの主要設定:"
        grep -E "^(project|environment|domain_name|ec2_name|rds_identifier)" "$terraform_tfvars" | head -10
        echo ""
    fi
    
    log_success "設定情報の表示が完了しました"
}

# メイン処理
main() {
    # 引数の解析
    local playbook="$DEFAULT_PLAYBOOK"
    local environment="$DEFAULT_ENVIRONMENT"
    local dry_run="false"
    local step_by_step="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --playbook)
                playbook="$2"
                shift 2
                ;;
            --environment)
                environment="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --step-by-step)
                step_by_step="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "=== $SCRIPT_NAME 開始 ==="
    log_info "プレイブック: $playbook"
    log_info "環境: $environment"
    log_info "ドライラン: $dry_run"
    log_info "段階的実行: $step_by_step"
    log_info "実行モード: 単体実行（terraform.tfvars直接読み込み）"
    
    # 設定情報の表示
    show_config_info
    
    # 設定ファイルの検証
    if ! validate_config_files; then
        log_error "設定ファイルの検証に失敗しました"
        exit 1
    fi
    
    # 環境設定
    setup_environment "$environment"
    
    # インベントリの準備
    if ! prepare_inventory; then
        log_error "インベントリの準備に失敗しました"
        exit 1
    fi
    
    # 変数ファイルの準備
    prepare_variables
    
    # 接続テスト
    if ! test_connections "$DEFAULT_INVENTORY"; then
        log_warn "接続テストに失敗しましたが、処理を続行します"
        log_info "IPアドレスが正しく設定されているか確認してください"
    fi
    
    # プレイブック実行
    if ! run_playbook "$playbook" "$DEFAULT_INVENTORY" "$dry_run" "$step_by_step"; then
        log_error "プレイブックの実行に失敗しました"
        exit 1
    fi
    
    # 環境テスト
    test_environment "$DEFAULT_INVENTORY"
    
    log_success "=== $SCRIPT_NAME 完了 ==="
    echo ""
    echo "Ansible単体実行が完了しました"
    echo "terraform.tfvarsから直接設定値を読み込んで実行しました"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
