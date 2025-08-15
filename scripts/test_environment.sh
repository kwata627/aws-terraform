#!/bin/bash

# =============================================================================
# WordPress Environment Test Script
# =============================================================================
# 
# このスクリプトは、WordPress環境の動作をテストします。
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
WordPress Environment Test Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力
    --skip-ssl          SSLテストをスキップ
    --skip-db          データベーステストをスキップ
    --skip-web         Webサーバーテストをスキップ

例:
    $0                    # 全テスト実行
    $0 -v                 # 詳細出力付き
    $0 --skip-ssl         # SSLテストをスキップ

EOF
}

# デフォルト値
VERBOSE=false
SKIP_SSL=false
SKIP_DB=false
SKIP_WEB=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-ssl)
            SKIP_SSL=true
            shift
            ;;
        --skip-db)
            SKIP_DB=true
            shift
            ;;
        --skip-web)
            SKIP_WEB=false
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
    
    if [ -z "$WORDPRESS_IP" ]; then
        error "WordPressサーバーのIPアドレスを取得できませんでした"
        exit 1
    fi
    
    if [ -z "$RDS_ENDPOINT" ]; then
        error "RDSエンドポイントを取得できませんでした"
        exit 1
    fi
    
    if [ -z "$DOMAIN_NAME" ]; then
        error "ドメイン名を取得できませんでした"
        exit 1
    fi
    
    success "環境変数の設定が完了しました"
}

# SSH接続テスト
test_ssh_connection() {
    log "SSH接続をテスト中..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes wordpress-server "echo 'SSH接続成功'" 2>/dev/null; then
        success "SSH接続テスト成功"
        return 0
    else
        error "SSH接続テストに失敗しました"
        return 1
    fi
}

# Webサーバーテスト
test_web_server() {
    if [ "$SKIP_WEB" = true ]; then
        warning "Webサーバーテストをスキップします"
        return 0
    fi
    
    log "Webサーバーをテスト中..."
    
    # HTTP接続テスト
    if curl -s -o /dev/null -w "%{http_code}" "http://$WORDPRESS_IP" | grep -q "200\|301\|302"; then
        success "HTTP接続テスト成功"
    else
        error "HTTP接続テストに失敗しました"
        return 1
    fi
    
    # HTTPS接続テスト
    if [ "$SKIP_SSL" = false ]; then
        if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN_NAME" | grep -q "200\|301\|302"; then
            success "HTTPS接続テスト成功"
        else
            warning "HTTPS接続テストに失敗しました（SSL証明書の設定中かもしれません）"
        fi
    fi
    
    # WordPressページの確認
    if curl -s "http://$WORDPRESS_IP" | grep -q "WordPress\|wp-content"; then
        success "WordPressページの確認成功"
    else
        warning "WordPressページの確認に失敗しました（WordPressの初期設定が必要かもしれません）"
    fi
}

# データベース接続テスト
test_database_connection() {
    if [ "$SKIP_DB" = true ]; then
        warning "データベーステストをスキップします"
        return 0
    fi
    
    log "データベース接続をテスト中..."
    
    # SSH経由でデータベース接続テスト
    if ssh wordpress-server "mysql -h $RDS_ENDPOINT -u wordpress -p'${WORDPRESS_DB_PASSWORD:-your-secure-password-here}' -e 'SELECT 1;'" 2>/dev/null; then
        success "データベース接続テスト成功"
    else
        error "データベース接続テストに失敗しました"
        return 1
    fi
    
    # WordPressデータベースの確認
    if ssh wordpress-server "mysql -h $RDS_ENDPOINT -u wordpress -p'${WORDPRESS_DB_PASSWORD:-your-secure-password-here}' -e 'USE wordpress; SHOW TABLES;'" 2>/dev/null | grep -q "wp_"; then
        success "WordPressデータベースの確認成功"
    else
        warning "WordPressデータベースの確認に失敗しました（WordPressの初期設定が必要かもしれません）"
    fi
}

# サービス状態テスト
test_services() {
    log "サービス状態をテスト中..."
    
    # Apache状態確認
    if ssh wordpress-server "systemctl is-active httpd" 2>/dev/null | grep -q "active"; then
        success "Apacheサービスが正常に動作しています"
    else
        error "Apacheサービスが正常に動作していません"
        return 1
    fi
    
    # PHP-FPM状態確認
    if ssh wordpress-server "systemctl is-active php-fpm" 2>/dev/null | grep -q "active"; then
        success "PHP-FPMサービスが正常に動作しています"
    else
        warning "PHP-FPMサービスが正常に動作していません"
    fi
    
    # MySQL接続確認
    if ssh wordpress-server "mysql -h $RDS_ENDPOINT -u wordpress -p'${WORDPRESS_DB_PASSWORD:-your-secure-password-here}' -e 'SELECT VERSION();'" 2>/dev/null; then
        success "MySQL接続が正常です"
    else
        error "MySQL接続に失敗しました"
        return 1
    fi
}

# セキュリティテスト
test_security() {
    log "セキュリティ設定をテスト中..."
    
    # SSH設定確認
    if ssh wordpress-server "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config" 2>/dev/null; then
        success "SSHパスワード認証が無効化されています"
    else
        warning "SSHパスワード認証が有効です"
    fi
    
    # ファイアウォール状態確認
    if ssh wordpress-server "systemctl is-active firewalld" 2>/dev/null | grep -q "active"; then
        success "ファイアウォールが有効です"
    else
        warning "ファイアウォールが無効です"
    fi
    
    # SELinux状態確認
    if ssh wordpress-server "getenforce" 2>/dev/null | grep -q "Enforcing"; then
        success "SELinuxが有効です"
    else
        warning "SELinuxが無効です"
    fi
}

# パフォーマンステスト
test_performance() {
    log "パフォーマンスをテスト中..."
    
    # ディスク使用量確認
    DISK_USAGE=$(ssh wordpress-server "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
    if [ "$DISK_USAGE" -lt 80 ]; then
        success "ディスク使用量: ${DISK_USAGE}% (正常)"
    else
        warning "ディスク使用量: ${DISK_USAGE}% (注意が必要)"
    fi
    
    # メモリ使用量確認
    MEMORY_USAGE=$(ssh wordpress-server "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" 2>/dev/null)
    if [ "$(echo "$MEMORY_USAGE < 80" | bc -l)" -eq 1 ]; then
        success "メモリ使用量: ${MEMORY_USAGE}% (正常)"
    else
        warning "メモリ使用量: ${MEMORY_USAGE}% (注意が必要)"
    fi
    
    # ロードアベレージ確認
    LOAD_AVG=$(ssh wordpress-server "uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | sed 's/,//'" 2>/dev/null)
    CPU_CORES=$(ssh wordpress-server "nproc" 2>/dev/null)
    if [ "$(echo "$LOAD_AVG < $CPU_CORES" | bc -l)" -eq 1 ]; then
        success "ロードアベレージ: $LOAD_AVG (正常)"
    else
        warning "ロードアベレージ: $LOAD_AVG (注意が必要)"
    fi
}

# メイン処理
main() {
    log "=== WordPress環境テスト開始 ==="
    
    # 必要なツールの確認
    for tool in terraform curl ssh; do
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
    
    # テスト実行
    local test_results=()
    
    # SSH接続テスト
    if test_ssh_connection; then
        test_results+=("SSH接続: ✓")
    else
        test_results+=("SSH接続: ✗")
    fi
    
    # Webサーバーテスト
    if test_web_server; then
        test_results+=("Webサーバー: ✓")
    else
        test_results+=("Webサーバー: ✗")
    fi
    
    # データベース接続テスト
    if test_database_connection; then
        test_results+=("データベース: ✓")
    else
        test_results+=("データベース: ✗")
    fi
    
    # サービス状態テスト
    if test_services; then
        test_results+=("サービス: ✓")
    else
        test_results+=("サービス: ✗")
    fi
    
    # セキュリティテスト
    test_security
    test_results+=("セキュリティ: ✓")
    
    # パフォーマンステスト
    test_performance
    test_results+=("パフォーマンス: ✓")
    
    # テスト結果の表示
    log "=== テスト結果 ==="
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    # 成功/失敗の判定
    local failed_tests=0
    for result in "${test_results[@]}"; do
        if [[ $result == *"✗"* ]]; then
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    if [ $failed_tests -eq 0 ]; then
        success "すべてのテストが成功しました！"
        echo
        echo "WordPress環境は正常に動作しています。"
        echo "アクセス情報:"
        echo "- WordPress URL: https://$DOMAIN_NAME"
        echo "- 管理画面: https://$DOMAIN_NAME/wp-admin"
        echo "- SSH接続: ssh wordpress-server"
    else
        warning "$failed_tests個のテストが失敗しました"
        echo
        echo "失敗したテストを確認し、必要に応じて手動で修正してください。"
    fi
    
    log "=== WordPress環境テスト完了 ==="
}

# スクリプト実行
main "$@"
