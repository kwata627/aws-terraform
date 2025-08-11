#!/bin/bash

# =============================================================================
# Deployment Environment Test Script
# =============================================================================
# 
# このスクリプトは、デプロイメント環境の動作をテストします。
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
Deployment Environment Test Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力
    --skip-git          Gitテストをスキップ
    --skip-backup       バックアップテストをスキップ
    --skip-rollback     ロールバックテストをスキップ

例:
    $0                    # 全テスト実行
    $0 -v                 # 詳細出力付き
    $0 --skip-git         # Gitテストをスキップ

EOF
}

# デフォルト値
VERBOSE=false
SKIP_GIT=false
SKIP_BACKUP=false
SKIP_ROLLBACK=false

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
        --skip-git)
            SKIP_GIT=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-rollback)
            SKIP_ROLLBACK=true
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
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    if [ -z "$WORDPRESS_IP" ]; then
        error "WordPressサーバーのIPアドレスを取得できませんでした"
        exit 1
    fi
    
    if [ -z "$DOMAIN_NAME" ]; then
        error "ドメイン名を取得できませんでした"
        exit 1
    fi
    
    if [ -z "$S3_BUCKET" ]; then
        warning "S3バケット名を取得できませんでした"
    fi
    
    success "環境変数の設定が完了しました"
}

# Git環境テスト
test_git_environment() {
    if [ "$SKIP_GIT" = true ]; then
        warning "Gitテストをスキップします"
        return 0
    fi
    
    log "Git環境をテスト中..."
    
    # Gitの確認
    if ! command -v git &> /dev/null; then
        error "Gitコマンドが見つかりません"
        return 1
    fi
    
    # Gitリポジトリの確認
    if [ -d ".git" ]; then
        success "Gitリポジトリが存在します"
        
        # リモートリポジトリの確認
        if git remote -v &> /dev/null; then
            success "リモートリポジトリが設定されています"
        else
            warning "リモートリポジトリが設定されていません"
        fi
        
        # ブランチの確認
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        success "現在のブランチ: $CURRENT_BRANCH"
        
        # コミット状態の確認
        if git status --porcelain | grep -q .; then
            warning "未コミットの変更があります"
        else
            success "作業ディレクトリはクリーンです"
        fi
    else
        error "Gitリポジトリが見つかりません"
        return 1
    fi
}

# バックアップ環境テスト
test_backup_environment() {
    if [ "$SKIP_BACKUP" = true ]; then
        warning "バックアップテストをスキップします"
        return 0
    fi
    
    log "バックアップ環境をテスト中..."
    
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
    
    # S3バケットの確認
    if [ -n "$S3_BUCKET" ]; then
        if aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
            success "S3バケットにアクセス可能です: $S3_BUCKET"
            
            # バックアップディレクトリの確認
            if aws s3 ls "s3://$S3_BUCKET/backups/" &> /dev/null; then
                success "バックアップディレクトリが存在します"
            else
                warning "バックアップディレクトリが存在しません"
            fi
        else
            error "S3バケットにアクセスできません: $S3_BUCKET"
            return 1
        fi
    else
        warning "S3バケット名が設定されていません"
    fi
    
    # ローカルバックアップディレクトリの確認
    if [ -d "backups" ]; then
        success "ローカルバックアップディレクトリが存在します"
    else
        warning "ローカルバックアップディレクトリが存在しません"
    fi
}

# ロールバック環境テスト
test_rollback_environment() {
    if [ "$SKIP_ROLLBACK" = true ]; then
        warning "ロールバックテストをスキップします"
        return 0
    fi
    
    log "ロールバック環境をテスト中..."
    
    # ロールバックスクリプトの確認
    if [ -f "../scripts/rollback.sh" ]; then
        success "ロールバックスクリプトが存在します"
        
        # 実行権限の確認
        if [ -x "../scripts/rollback.sh" ]; then
            success "ロールバックスクリプトに実行権限があります"
        else
            warning "ロールバックスクリプトに実行権限がありません"
        fi
    else
        warning "ロールバックスクリプトが見つかりません"
    fi
    
    # デプロイメント設定ファイルの確認
    if [ -f "../deployment_config.json" ]; then
        success "デプロイメント設定ファイルが存在します"
        
        # 設定内容の確認
        if command -v jq &> /dev/null; then
            if jq -e '.' "../deployment_config.json" &> /dev/null; then
                success "デプロイメント設定ファイルの形式が正しいです"
            else
                error "デプロイメント設定ファイルの形式が正しくありません"
                return 1
            fi
        else
            warning "jqコマンドが見つからないため、設定ファイルの検証をスキップします"
        fi
    else
        warning "デプロイメント設定ファイルが見つかりません"
    fi
}

# デプロイメントスクリプトテスト
test_deployment_scripts() {
    log "デプロイメントスクリプトをテスト中..."
    
    # 自動デプロイメントスクリプトの確認
    if [ -f "auto_deployment.sh" ]; then
        success "自動デプロイメントスクリプトが存在します"
        
        if [ -x "auto_deployment.sh" ]; then
            success "自動デプロイメントスクリプトに実行権限があります"
        else
            warning "自動デプロイメントスクリプトに実行権限がありません"
        fi
    else
        warning "自動デプロイメントスクリプトが見つかりません"
    fi
    
    # 本番デプロイメントスクリプトの確認
    if [ -f "deploy_to_production.sh" ]; then
        success "本番デプロイメントスクリプトが存在します"
        
        if [ -x "deploy_to_production.sh" ]; then
            success "本番デプロイメントスクリプトに実行権限があります"
        else
            warning "本番デプロイメントスクリプトに実行権限がありません"
        fi
    else
        warning "本番デプロイメントスクリプトが見つかりません"
    fi
    
    # 検証環境準備スクリプトの確認
    if [ -f "prepare_validation.sh" ]; then
        success "検証環境準備スクリプトが存在します"
        
        if [ -x "prepare_validation.sh" ]; then
            success "検証環境準備スクリプトに実行権限があります"
        else
            warning "検証環境準備スクリプトに実行権限がありません"
        fi
    else
        warning "検証環境準備スクリプトが見つかりません"
    fi
}

# Ansible環境テスト
test_ansible_environment() {
    log "Ansible環境をテスト中..."
    
    # Ansibleの確認
    if ! command -v ansible &> /dev/null; then
        error "Ansibleコマンドが見つかりません"
        return 1
    fi
    
    # Ansible設定ファイルの確認
    if [ -f "../ansible/ansible.cfg" ]; then
        success "Ansible設定ファイルが存在します"
    else
        warning "Ansible設定ファイルが見つかりません"
    fi
    
    # インベントリファイルの確認
    if [ -f "../ansible/inventory/hosts.yml" ]; then
        success "Ansibleインベントリファイルが存在します"
        
        # インベントリの検証
        if command -v ansible-inventory &> /dev/null; then
            if ansible-inventory --list -i "../ansible/inventory/hosts.yml" &> /dev/null; then
                success "Ansibleインベントリが正常です"
            else
                warning "Ansibleインベントリに問題があります"
            fi
        else
            warning "ansible-inventoryコマンドが見つかりません"
        fi
    else
        warning "Ansibleインベントリファイルが見つかりません"
    fi
    
    # プレイブックの確認
    if [ -d "../ansible/playbooks" ]; then
        success "Ansibleプレイブックディレクトリが存在します"
        
        # 主要プレイブックの確認
        for playbook in "wordpress_setup.yml" "step_by_step_setup.yml" "ssl_setup.yml"; do
            if [ -f "../ansible/playbooks/$playbook" ]; then
                success "プレイブックが存在します: $playbook"
            else
                warning "プレイブックが見つかりません: $playbook"
            fi
        done
    else
        warning "Ansibleプレイブックディレクトリが見つかりません"
    fi
}

# 通知環境テスト
test_notification_environment() {
    log "通知環境をテスト中..."
    
    # メール送信コマンドの確認
    for mail_cmd in "mail" "sendmail" "mutt"; do
        if command -v $mail_cmd &> /dev/null; then
            success "メール送信コマンドが見つかりました: $mail_cmd"
            break
        fi
    done
    
    # Slack通知の確認（オプション）
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        success "Slack Webhook URLが設定されています"
    else
        warning "Slack Webhook URLが設定されていません"
    fi
    
    # 通知設定ファイルの確認
    if [ -f "../deployment_config.json" ]; then
        if command -v jq &> /dev/null; then
            NOTIFICATION_EMAIL=$(jq -r '.deployment.notification_email // empty' "../deployment_config.json" 2>/dev/null)
            if [ -n "$NOTIFICATION_EMAIL" ]; then
                success "通知メールアドレスが設定されています: $NOTIFICATION_EMAIL"
            else
                warning "通知メールアドレスが設定されていません"
            fi
        fi
    fi
}

# メイン処理
main() {
    log "=== デプロイメント環境テスト開始 ==="
    
    # 必要なツールの確認
    for tool in terraform ssh aws; do
        if ! command -v $tool &> /dev/null; then
            error "$toolコマンドが見つかりません"
            exit 1
        fi
    done
    
    # Terraform状態の確認
    if [ ! -f "../terraform.tfstate" ]; then
        error "terraform.tfstateファイルが見つかりません。terraform applyを先に実行してください。"
        exit 1
    fi
    
    # 作業ディレクトリの変更
    cd "$(dirname "$0")"
    
    # 環境変数の設定
    setup_environment
    
    # テスト実行
    local test_results=()
    
    # Git環境テスト
    if test_git_environment; then
        test_results+=("Git環境: ✓")
    else
        test_results+=("Git環境: ✗")
    fi
    
    # バックアップ環境テスト
    if test_backup_environment; then
        test_results+=("バックアップ環境: ✓")
    else
        test_results+=("バックアップ環境: ✗")
    fi
    
    # ロールバック環境テスト
    test_rollback_environment
    test_results+=("ロールバック環境: ✓")
    
    # デプロイメントスクリプトテスト
    test_deployment_scripts
    test_results+=("デプロイメントスクリプト: ✓")
    
    # Ansible環境テスト
    if test_ansible_environment; then
        test_results+=("Ansible環境: ✓")
    else
        test_results+=("Ansible環境: ✗")
    fi
    
    # 通知環境テスト
    test_notification_environment
    test_results+=("通知環境: ✓")
    
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
        success "すべてのデプロイメント環境テストが成功しました！"
        echo
        echo "デプロイメント環境は正常に設定されています。"
        echo
        echo "利用可能なコマンド:"
        echo "- 自動デプロイメント: ./auto_deployment.sh"
        echo "- 本番デプロイメント: ./deploy_to_production.sh"
        echo "- 検証環境準備: ./prepare_validation.sh"
        echo "- ロールバック: ../scripts/rollback.sh"
    else
        warning "$failed_tests個のデプロイメント環境テストが失敗しました"
        echo
        echo "失敗したテストを確認し、必要に応じて手動で修正してください。"
    fi
    
    log "=== デプロイメント環境テスト完了 ==="
}

# スクリプト実行
main "$@"
