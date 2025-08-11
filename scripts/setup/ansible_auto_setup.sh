#!/bin/bash

# =============================================================================
# Ansible Auto-Setup Script
# =============================================================================
# 
# このスクリプトは、Ansible設定からWordPress環境構築までを自動化します。
# terraform apply完了後に実行することを想定しています。
# =============================================================================

set -e

# 色付きログ関数
log() {
    echo -e "\033[1;34m[$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
Ansible Auto-Setup Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -s, --step-by-step  段階的実行（推奨）
    -f, --full          完全自動実行
    -i, --inventory-only インベントリ生成のみ
    -t, --test-only     テストのみ実行
    -v, --verbose       詳細出力
    --skip-ssl          SSL設定をスキップ
    --skip-test         環境テストをスキップ

例:
    $0 -s                # 段階的実行（推奨）
    $0 -f                # 完全自動実行
    $0 -i                # インベントリ生成のみ
    $0 -t                # テストのみ実行

EOF
}

# デフォルト値
STEP_BY_STEP=false
FULL_AUTO=false
INVENTORY_ONLY=false
TEST_ONLY=false
VERBOSE=false
SKIP_SSL=false
SKIP_TEST=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--step-by-step)
            STEP_BY_STEP=true
            shift
            ;;
        -f|--full)
            FULL_AUTO=true
            shift
            ;;
        -i|--inventory-only)
            INVENTORY_ONLY=true
            shift
            ;;
        -t|--test-only)
            TEST_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-ssl)
            SKIP_SSL=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        *)
            error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 環境変数の設定
setup_environment() {
    log "環境変数を設定中..."
    
    # Terraformから値を取得
    WORDPRESS_IP=$(terraform output -raw wordpress_public_ip 2>/dev/null || echo "")
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
    DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    
    # 環境変数の設定
    export WORDPRESS_DB_HOST="$RDS_ENDPOINT"
    export WORDPRESS_DB_PASSWORD="${DB_PASSWORD:-password}"
    export WORDPRESS_DB_NAME="wordpress"
    export WORDPRESS_DB_USER="wordpress"
    
    if [ "$VERBOSE" = true ]; then
        echo "環境変数:"
        echo "  WORDPRESS_DB_HOST: $WORDPRESS_DB_HOST"
        echo "  WORDPRESS_DB_NAME: $WORDPRESS_DB_NAME"
        echo "  WORDPRESS_DB_USER: $WORDPRESS_DB_USER"
        echo "  DOMAIN_NAME: $DOMAIN_NAME"
    fi
    
    success "環境変数の設定が完了しました"
}

# Ansibleインベントリの生成
generate_inventory() {
    log "Ansibleインベントリを生成中..."
    
    cd ansible
    
    # インベントリ生成スクリプトの実行
    if python3 generate_inventory.py; then
        success "インベントリファイルが生成されました"
        
        if [ "$VERBOSE" = true ]; then
            echo "インベントリ内容:"
            cat inventory/hosts.yml
        fi
    else
        error "インベントリファイルの生成に失敗しました"
        exit 1
    fi
    
    # Ansible設定の確認
    if command -v ansible-inventory &> /dev/null; then
        log "Ansible設定を確認中..."
        if ansible-inventory --list -i inventory/hosts.yml &> /dev/null; then
            success "Ansible設定が正常です"
        else
            warning "Ansible設定に問題があります"
        fi
    else
        warning "ansible-inventoryコマンドが見つかりません"
    fi
    
    cd ..
}

# SSH接続テスト
test_ssh_connection() {
    log "SSH接続をテスト中..."
    
    cd ansible
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ansible wordpress -m ping -i inventory/hosts.yml &> /dev/null; then
            success "SSH接続成功（試行 $attempt/$max_attempts）"
            cd ..
            return 0
        else
            warning "SSH接続に失敗しました（試行 $attempt/$max_attempts）"
            if [ $attempt -lt $max_attempts ]; then
                log "30秒待機中..."
                sleep 30
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    error "SSH接続に失敗しました（最大試行回数: $max_attempts）"
    cd ..
    return 1
}

# WordPress環境構築
setup_wordpress() {
    log "WordPress環境構築を開始中..."
    
    cd ansible
    
    if [ "$STEP_BY_STEP" = true ]; then
        log "段階的セットアップを実行中..."
        if ansible-playbook -i inventory/hosts.yml playbooks/step_by_step_setup.yml; then
            success "WordPress環境構築が完了しました"
        else
            error "WordPress環境構築に失敗しました"
            cd ..
            exit 1
        fi
    else
        log "完全セットアップを実行中..."
        if ansible-playbook -i inventory/hosts.yml playbooks/wordpress_setup.yml; then
            success "WordPress環境構築が完了しました"
        else
            error "WordPress環境構築に失敗しました"
            cd ..
            exit 1
        fi
    fi
    
    cd ..
}

# SSL証明書の設定
setup_ssl() {
    if [ "$SKIP_SSL" = true ]; then
        warning "SSL設定をスキップします"
        return 0
    fi
    
    log "SSL証明書の設定を開始中..."
    
    cd ansible
    
    if ansible-playbook -i inventory/hosts.yml playbooks/ssl_setup.yml; then
        success "SSL証明書の設定が完了しました"
    else
        error "SSL証明書の設定に失敗しました"
        cd ..
        exit 1
    fi
    
    cd ..
    
    # SSL設定の検証
    log "SSL設定を検証中..."
    if [ -f "../scripts/validate-ssl-setup.sh" ]; then
        cd ..
        if ./scripts/validate-ssl-setup.sh; then
            success "SSL設定の検証が完了しました"
        else
            warning "SSL設定の検証に失敗しました"
        fi
    else
        warning "SSL検証スクリプトが見つかりません"
    fi
}

# 環境テスト
run_environment_tests() {
    if [ "$SKIP_TEST" = true ]; then
        warning "環境テストをスキップします"
        return 0
    fi
    
    log "環境テストを開始中..."
    
    # WordPress環境のテスト
    if [ -f "./scripts/test_environment.sh" ]; then
        log "WordPress環境をテスト中..."
        if ./scripts/test_environment.sh; then
            success "WordPress環境テストが完了しました"
        else
            warning "WordPress環境テストに失敗しました"
        fi
    else
        warning "WordPress環境テストスクリプトが見つかりません"
    fi
    
    # 監視設定のテスト
    if [ -f "./scripts/test_monitoring.sh" ]; then
        log "監視設定をテスト中..."
        if ./scripts/test_monitoring.sh; then
            success "監視設定テストが完了しました"
        else
            warning "監視設定テストに失敗しました"
        fi
    else
        warning "監視設定テストスクリプトが見つかりません"
    fi
    
    # デプロイメントテスト
    if [ -f "./scripts/deployment/test_environment.sh" ]; then
        log "デプロイメント環境をテスト中..."
        if ./scripts/deployment/test_environment.sh; then
            success "デプロイメント環境テストが完了しました"
        else
            warning "デプロイメント環境テストに失敗しました"
        fi
    else
        warning "デプロイメント環境テストスクリプトが見つかりません"
    fi
}

# メイン処理
main() {
    log "=== Ansible Auto-Setup 開始 ==="
    
    # 必要なツールの確認
    for tool in terraform ansible python3; do
        if ! command -v $tool &> /dev/null; then
            error "$toolコマンドが見つかりません"
            exit 1
        fi
    done
    
    # Terraform状態の確認
    if [ ! -f "terraform.tfstate" ]; then
        error "terraform.tfstateファイルが見つかりません。terraform applyを先に実行してください。"
        exit 1
    fi
    
    # 環境変数の設定
    setup_environment
    
    # インベントリ生成のみの場合
    if [ "$INVENTORY_ONLY" = true ]; then
        generate_inventory
        log "=== インベントリ生成完了 ==="
        return 0
    fi
    
    # テストのみの場合
    if [ "$TEST_ONLY" = true ]; then
        run_environment_tests
        log "=== 環境テスト完了 ==="
        return 0
    fi
    
    # Ansibleインベントリの生成
    generate_inventory
    
    # SSH接続テスト
    test_ssh_connection
    
    # WordPress環境構築
    setup_wordpress
    
    # SSL証明書の設定
    setup_ssl
    
    # 環境テスト
    run_environment_tests
    
    # 設定完了メッセージ
    log "=== Ansible Auto-Setup 完了 ==="
    echo
    success "WordPress環境の構築が完了しました！"
    echo
    echo "アクセス情報:"
    echo "- WordPress URL: https://$DOMAIN_NAME"
    echo "- 管理画面: https://$DOMAIN_NAME/wp-admin"
    echo "- SSH接続: ssh wordpress-server"
    echo
    echo "次のステップ:"
    echo "1. WordPressの初期設定を完了"
    echo "2. プラグインとテーマの設定"
    echo "3. セキュリティ設定の確認"
    echo "4. バックアップ設定の確認"
    echo
}

# スクリプト実行
main "$@"
