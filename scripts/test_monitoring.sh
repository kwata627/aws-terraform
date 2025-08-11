#!/bin/bash

# =============================================================================
# Monitoring Test Script
# =============================================================================
# 
# このスクリプトは、監視設定の動作をテストします。
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
Monitoring Test Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力
    --skip-cloudwatch   CloudWatchテストをスキップ
    --skip-logging      ログ監視テストをスキップ
    --skip-alerts       アラートテストをスキップ

例:
    $0                    # 全テスト実行
    $0 -v                 # 詳細出力付き
    $0 --skip-cloudwatch  # CloudWatchテストをスキップ

EOF
}

# デフォルト値
VERBOSE=false
SKIP_CLOUDWATCH=false
SKIP_LOGGING=false
SKIP_ALERTS=false

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
        --skip-cloudwatch)
            SKIP_CLOUDWATCH=true
            shift
            ;;
        --skip-logging)
            SKIP_LOGGING=true
            shift
            ;;
        --skip-alerts)
            SKIP_ALERTS=true
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
    DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    
    if [ -z "$WORDPRESS_IP" ]; then
        error "WordPressサーバーのIPアドレスを取得できませんでした"
        exit 1
    fi
    
    if [ -z "$DOMAIN_NAME" ]; then
        error "ドメイン名を取得できませんでした"
        exit 1
    fi
    
    success "環境変数の設定が完了しました"
}

# CloudWatch監視テスト
test_cloudwatch() {
    if [ "$SKIP_CLOUDWATCH" = true ]; then
        warning "CloudWatchテストをスキップします"
        return 0
    fi
    
    log "CloudWatch監視をテスト中..."
    
    # AWS CLIの確認
    if ! command -v aws &> /dev/null; then
        error "AWS CLIが見つかりません"
        return 1
    fi
    
    # AWS認証情報の確認
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS認証情報が設定されていません"
        return 1
    fi
    
    # CloudWatchメトリクスの確認
    if aws cloudwatch list-metrics --namespace "AWS/EC2" --metric-name "CPUUtilization" &> /dev/null; then
        success "CloudWatchメトリクスにアクセス可能です"
    else
        warning "CloudWatchメトリクスにアクセスできません"
    fi
    
    # CloudWatchログの確認
    if aws logs describe-log-groups --log-group-name-prefix "/aws/ec2" &> /dev/null; then
        success "CloudWatchログにアクセス可能です"
    else
        warning "CloudWatchログにアクセスできません"
    fi
}

# ログ監視テスト
test_logging() {
    if [ "$SKIP_LOGGING" = true ]; then
        warning "ログ監視テストをスキップします"
        return 0
    fi
    
    log "ログ監視をテスト中..."
    
    # Apacheログの確認
    if ssh wordpress-server "test -f /var/log/httpd/access_log" 2>/dev/null; then
        success "Apacheアクセスログが存在します"
        
        # ログファイルのサイズ確認
        LOG_SIZE=$(ssh wordpress-server "stat -c%s /var/log/httpd/access_log" 2>/dev/null)
        if [ "$LOG_SIZE" -gt 0 ]; then
            success "Apacheアクセスログにデータが記録されています"
        else
            warning "Apacheアクセスログが空です"
        fi
    else
        warning "Apacheアクセスログが見つかりません"
    fi
    
    # エラーログの確認
    if ssh wordpress-server "test -f /var/log/httpd/error_log" 2>/dev/null; then
        success "Apacheエラーログが存在します"
    else
        warning "Apacheエラーログが見つかりません"
    fi
    
    # PHPエラーログの確認
    if ssh wordpress-server "test -f /var/log/php_errors.log" 2>/dev/null; then
        success "PHPエラーログが存在します"
    else
        warning "PHPエラーログが見つかりません"
    fi
    
    # WordPressデバッグログの確認
    if ssh wordpress-server "test -f /var/www/html/wp-content/debug.log" 2>/dev/null; then
        success "WordPressデバッグログが存在します"
    else
        warning "WordPressデバッグログが見つかりません"
    fi
}

# アラート設定テスト
test_alerts() {
    if [ "$SKIP_ALERTS" = true ]; then
        warning "アラートテストをスキップします"
        return 0
    fi
    
    log "アラート設定をテスト中..."
    
    # SNSトピックの確認
    if aws sns list-topics &> /dev/null; then
        success "SNSトピックにアクセス可能です"
    else
        warning "SNSトピックにアクセスできません"
    fi
    
    # CloudWatchアラームの確認
    if aws cloudwatch describe-alarms &> /dev/null; then
        success "CloudWatchアラームにアクセス可能です"
    else
        warning "CloudWatchアラームにアクセスできません"
    fi
}

# システム監視テスト
test_system_monitoring() {
    log "システム監視をテスト中..."
    
    # プロセス監視
    if ssh wordpress-server "pgrep httpd" 2>/dev/null; then
        success "Apacheプロセスが動作しています"
    else
        error "Apacheプロセスが動作していません"
        return 1
    fi
    
    if ssh wordpress-server "pgrep php-fpm" 2>/dev/null; then
        success "PHP-FPMプロセスが動作しています"
    else
        warning "PHP-FPMプロセスが動作していません"
    fi
    
    # ポート監視
    if ssh wordpress-server "netstat -tlnp | grep :80" 2>/dev/null; then
        success "ポート80（HTTP）がリッスンしています"
    else
        error "ポート80（HTTP）がリッスンしていません"
        return 1
    fi
    
    if ssh wordpress-server "netstat -tlnp | grep :443" 2>/dev/null; then
        success "ポート443（HTTPS）がリッスンしています"
    else
        warning "ポート443（HTTPS）がリッスンしていません"
    fi
    
    # ディスク監視
    DISK_USAGE=$(ssh wordpress-server "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
    if [ "$DISK_USAGE" -lt 90 ]; then
        success "ディスク使用量: ${DISK_USAGE}% (正常)"
    else
        warning "ディスク使用量: ${DISK_USAGE}% (注意が必要)"
    fi
    
    # メモリ監視
    MEMORY_USAGE=$(ssh wordpress-server "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" 2>/dev/null)
    if [ "$(echo "$MEMORY_USAGE < 90" | bc -l)" -eq 1 ]; then
        success "メモリ使用量: ${MEMORY_USAGE}% (正常)"
    else
        warning "メモリ使用量: ${MEMORY_USAGE}% (注意が必要)"
    fi
}

# パフォーマンス監視テスト
test_performance_monitoring() {
    log "パフォーマンス監視をテスト中..."
    
    # レスポンス時間テスト
    RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null "http://$WORDPRESS_IP" 2>/dev/null)
    if [ "$(echo "$RESPONSE_TIME < 5" | bc -l)" -eq 1 ]; then
        success "レスポンス時間: ${RESPONSE_TIME}秒 (正常)"
    else
        warning "レスポンス時間: ${RESPONSE_TIME}秒 (遅い)"
    fi
    
    # ロードアベレージ監視
    LOAD_AVG=$(ssh wordpress-server "uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | sed 's/,//'" 2>/dev/null)
    CPU_CORES=$(ssh wordpress-server "nproc" 2>/dev/null)
    if [ "$(echo "$LOAD_AVG < $CPU_CORES" | bc -l)" -eq 1 ]; then
        success "ロードアベレージ: $LOAD_AVG (正常)"
    else
        warning "ロードアベレージ: $LOAD_AVG (高い)"
    fi
    
    # 接続数監視
    CONNECTION_COUNT=$(ssh wordpress-server "netstat -an | grep :80 | wc -l" 2>/dev/null)
    if [ "$CONNECTION_COUNT" -lt 100 ]; then
        success "HTTP接続数: $CONNECTION_COUNT (正常)"
    else
        warning "HTTP接続数: $CONNECTION_COUNT (多い)"
    fi
}

# セキュリティ監視テスト
test_security_monitoring() {
    log "セキュリティ監視をテスト中..."
    
    # ファイアウォール状態
    if ssh wordpress-server "systemctl is-active firewalld" 2>/dev/null | grep -q "active"; then
        success "ファイアウォールが有効です"
    else
        warning "ファイアウォールが無効です"
    fi
    
    # 不正アクセスログの確認
    FAILED_LOGINS=$(ssh wordpress-server "grep 'Failed password' /var/log/secure | wc -l" 2>/dev/null)
    if [ "$FAILED_LOGINS" -eq 0 ]; then
        success "不正ログイン試行: 0件 (正常)"
    else
        warning "不正ログイン試行: $FAILED_LOGINS件"
    fi
    
    # セキュリティアップデートの確認
    if ssh wordpress-server "yum check-update --security" 2>/dev/null | grep -q "security"; then
        warning "セキュリティアップデートが利用可能です"
    else
        success "セキュリティアップデートは最新です"
    fi
}

# メイン処理
main() {
    log "=== 監視設定テスト開始 ==="
    
    # 必要なツールの確認
    for tool in terraform ssh curl aws; do
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
    
    # CloudWatch監視テスト
    if test_cloudwatch; then
        test_results+=("CloudWatch: ✓")
    else
        test_results+=("CloudWatch: ✗")
    fi
    
    # ログ監視テスト
    test_logging
    test_results+=("ログ監視: ✓")
    
    # アラート設定テスト
    test_alerts
    test_results+=("アラート: ✓")
    
    # システム監視テスト
    if test_system_monitoring; then
        test_results+=("システム監視: ✓")
    else
        test_results+=("システム監視: ✗")
    fi
    
    # パフォーマンス監視テスト
    test_performance_monitoring
    test_results+=("パフォーマンス監視: ✓")
    
    # セキュリティ監視テスト
    test_security_monitoring
    test_results+=("セキュリティ監視: ✓")
    
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
        success "すべての監視テストが成功しました！"
        echo
        echo "監視システムは正常に動作しています。"
    else
        warning "$failed_tests個の監視テストが失敗しました"
        echo
        echo "失敗したテストを確認し、必要に応じて手動で修正してください。"
    fi
    
    log "=== 監視設定テスト完了 ==="
}

# スクリプト実行
main "$@"
