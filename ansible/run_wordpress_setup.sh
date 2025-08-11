#!/bin/bash

# =============================================================================
# WordPress環境構築実行スクリプト
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="WordPress環境構築"
readonly DEFAULT_PLAYBOOK="playbooks/wordpress_setup.yml"
readonly DEFAULT_INVENTORY="inventory/hosts.yml"
readonly DEFAULT_ENVIRONMENT="production"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
WordPress環境構築実行スクリプト

使用方法:
  $0                                    # デフォルト設定で実行
  $0 --playbook <PLAYBOOK>              # 指定したプレイブックで実行
  $0 --environment <ENVIRONMENT>         # 指定した環境で実行
  $0 --dry-run                          # ドライラン実行
  $0 --step-by-step                     # 段階的実行
  $0 --help                            # このヘルプを表示

機能:
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

例:
  $0 --environment production
  $0 --playbook playbooks/step_by_step_setup.yml --dry-run
  ENVIRONMENT=development $0

EOF
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
    
    log_success "環境設定が完了しました: $environment"
}

# インベントリの準備
prepare_inventory() {
    log_step "インベントリを準備中..."
    
    # インベントリディレクトリの確認
    check_directory_exists "inventory" "インベントリディレクトリ"
    
    # インベントリ生成スクリプトの実行
    generate_inventory
    
    # 生成されたインベントリファイルの確認
    check_inventory "$DEFAULT_INVENTORY"
    
    log_success "インベントリの準備が完了しました"
}

# 変数ファイルの確認
check_variables() {
    log_step "変数ファイルを確認中..."
    
    # 必須変数ファイルの確認
    local required_vars=("group_vars/all.yml" "group_vars/wordpress.yml")
    
    for var_file in "${required_vars[@]}"; do
        if [ -f "$var_file" ]; then
            validate_config_file "$var_file" "yaml"
            log_info "変数ファイルを確認しました: $var_file"
        else
            log_warn "変数ファイルが見つかりません: $var_file"
        fi
    done
    
    log_success "変数ファイルの確認が完了しました"
}

# 接続テストの実行
run_connection_test() {
    log_step "接続テストを実行中..."
    
    # WordPressグループへの接続テスト
    if test_connection "$DEFAULT_INVENTORY" "wordpress"; then
        log_success "WordPressサーバーへの接続テストが成功しました"
    else
        error_exit "WordPressサーバーへの接続テストに失敗しました"
    fi
    
    # NATインスタンスへの接続テスト（存在する場合）
    if ansible -i "$DEFAULT_INVENTORY" nat_instance --list-hosts 2>/dev/null | grep -q "nat_instance"; then
        if test_connection "$DEFAULT_INVENTORY" "nat_instance"; then
            log_success "NATインスタンスへの接続テストが成功しました"
        else
            log_warn "NATインスタンスへの接続テストに失敗しました"
        fi
    else
        log_info "NATインスタンスは設定されていません"
    fi
}

# プレイブックの実行
execute_playbook() {
    local playbook_file="${1:-$DEFAULT_PLAYBOOK}"
    local dry_run="${2:-false}"
    local extra_vars="${3:-}"
    
    log_step "プレイブックを実行中: $playbook_file"
    
    # プレイブックファイルの確認
    check_playbook "$playbook_file"
    
    # 構文チェック
    check_syntax "$playbook_file"
    
    # ドライランまたは実際の実行
    if [ "$dry_run" = "true" ]; then
        run_dry_run "$playbook_file" "$DEFAULT_INVENTORY"
    else
        # 実行前の確認
        if [ "${AUTO_APPROVE:-false}" != "true" ]; then
            log_input "プレイブックを実行しますか？ (y/N): "
            read -p "> " confirm
            if [ "$confirm" != "y" ]; then
                log_info "プレイブックの実行をキャンセルしました"
                return 0
            fi
        fi
        
        # プレイブックの実行
        run_playbook "$playbook_file" "$DEFAULT_INVENTORY" "$extra_vars"
    fi
    
    log_success "プレイブックの実行が完了しました"
}

# 段階的実行
run_step_by_step() {
    log_step "段階的実行を開始..."
    
    local step_playbook="playbooks/step_by_step_setup.yml"
    
    # 各ステップの実行
    local steps=("step1" "step2" "step3" "step4" "step5")
    
    for step in "${steps[@]}"; do
        log_info "ステップ $step を実行中..."
        
        if run_playbook "$step_playbook" "$DEFAULT_INVENTORY" "" "$step"; then
            log_success "ステップ $step が完了しました"
            
            # 次のステップへの確認
            if [ "${AUTO_APPROVE:-false}" != "true" ]; then
                log_input "次のステップに進みますか？ (y/N): "
                read -p "> " continue_step
                if [ "$continue_step" != "y" ]; then
                    log_info "段階的実行を停止しました"
                    break
                fi
            fi
        else
            error_exit "ステップ $step でエラーが発生しました"
        fi
    done
    
    log_success "段階的実行が完了しました"
}

# 環境テストの実行
run_environment_test() {
    log_step "環境テストを実行中..."
    
    # 基本的な接続テスト
    run_connection_test
    
    # WordPressサイトの動作確認
    local wordpress_ip
    wordpress_ip=$(ansible -i "$DEFAULT_INVENTORY" wordpress -m setup -a "filter=ansible_default_ipv4" | grep "address" | head -1 | awk '{print $2}' | tr -d '"')
    
    if [ -n "$wordpress_ip" ]; then
        log_info "WordPressサイトの動作確認中: http://$wordpress_ip"
        
        if curl -f -s -o /dev/null --max-time 30 "http://$wordpress_ip"; then
            log_success "WordPressサイトが正常に動作しています"
        else
            log_warn "WordPressサイトへの接続に失敗しました"
        fi
    else
        log_warn "WordPressサーバーのIPアドレスを取得できませんでした"
    fi
    
    log_success "環境テストが完了しました"
}

# 後処理
post_setup() {
    log_step "後処理を実行中..."
    
    # バックアップの作成
    if [ "${BACKUP_ENABLED:-true}" = "true" ]; then
        create_backup "group_vars"
        create_backup "inventory"
    fi
    
    # 古いバックアップの削除
    cleanup_old_backups "./backups" "${BACKUP_RETENTION_DAYS:-7}"
    
    # 成功メッセージの表示
    log_success "WordPress環境構築が完了しました"
    
    # アクセス情報の表示
    local wordpress_ip
    wordpress_ip=$(ansible -i "$DEFAULT_INVENTORY" wordpress -m setup -a "filter=ansible_default_ipv4" | grep "address" | head -1 | awk '{print $2}' | tr -d '"')
    
    if [ -n "$wordpress_ip" ]; then
        echo ""
        echo "=== WordPress環境構築完了 ==="
        echo "WordPressサイト: http://$wordpress_ip"
        echo "管理画面: http://$wordpress_ip/wp-admin"
        echo ""
        echo "ログファイル: ${LOG_FILE:-$DEFAULT_LOG_FILE}"
        echo ""
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    # 共通初期化
    init_ansible_common "$SCRIPT_NAME"
    
    # 引数の解析
    local playbook_file="$DEFAULT_PLAYBOOK"
    local environment="$DEFAULT_ENVIRONMENT"
    local dry_run=false
    local step_by_step=false
    local extra_vars=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --playbook)
                playbook_file="$2"
                shift 2
                ;;
            --environment)
                environment="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --step-by-step)
                step_by_step=true
                shift
                ;;
            --extra-vars)
                extra_vars="$2"
                shift 2
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
    
    # 環境変数からの設定読み込み
    if [ -n "${ENVIRONMENT:-}" ]; then
        environment="$ENVIRONMENT"
    fi
    
    if [ -n "${PLAYBOOK:-}" ]; then
        playbook_file="$PLAYBOOK"
    fi
    
    if [ "${DRY_RUN:-}" = "true" ]; then
        dry_run=true
    fi
    
    # 環境設定
    setup_environment "$environment"
    
    # インベントリの準備
    prepare_inventory
    
    # 変数ファイルの確認
    check_variables
    
    # 接続テスト
    run_connection_test
    
    # プレイブックの実行
    if [ "$step_by_step" = true ]; then
        run_step_by_step
    else
        execute_playbook "$playbook_file" "$dry_run" "$extra_vars"
    fi
    
    # 環境テスト
    run_environment_test
    
    # 後処理
    post_setup
    
    finish_ansible_script "$SCRIPT_NAME" 0
}

# スクリプト実行
main "$@" 