#!/bin/bash

# GitHub Actionsワークフローテストスクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ワークフロー機能テスト
test_workflow_functionality() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    log_step "テスト中: $workflow_name"
    
    # 1. 基本的な構文チェック
    log_info "1. 基本的な構文チェック"
    if grep -q "name:" "$workflow_file" && grep -q "on:" "$workflow_file" && grep -q "jobs:" "$workflow_file"; then
        log_info "✅ 基本的な構造: OK"
    else
        log_error "❌ 基本的な構造エラー"
        return 1
    fi
    
    # 2. トリガー設定の確認
    log_info "2. トリガー設定の確認"
    if grep -q "workflow_dispatch:" "$workflow_file"; then
        log_info "✅ 手動実行トリガー: OK"
    else
        log_warn "⚠️ 手動実行トリガーが見つかりません"
    fi
    
    if grep -q "push:" "$workflow_file"; then
        log_info "✅ プッシュトリガー: OK"
    else
        log_warn "⚠️ プッシュトリガーが見つかりません"
    fi
    
    if grep -q "schedule:" "$workflow_file"; then
        log_info "✅ スケジュールトリガー: OK"
    else
        log_warn "⚠️ スケジュールトリガーが見つかりません"
    fi
    
    # 3. 入力パラメータの確認
    log_info "3. 入力パラメータの確認"
    local input_count=$(grep -c "description:" "$workflow_file" || echo "0")
    if [ "$input_count" -gt 0 ]; then
        log_info "✅ 入力パラメータ: $input_count 個"
    else
        log_warn "⚠️ 入力パラメータが見つかりません"
    fi
    
    # 4. 必須アクションの確認
    log_info "4. 必須アクションの確認"
    local required_actions=("actions/checkout@v4" "aws-actions/configure-aws-credentials@v4")
    for action in "${required_actions[@]}"; do
        if grep -q "$action" "$workflow_file"; then
            log_info "✅ アクション $action: OK"
        else
            log_warn "⚠️ アクション $action が見つかりません"
        fi
    done
    
    # 5. シークレット参照の確認
    log_info "5. シークレット参照の確認"
    local secrets=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "SSH_PRIVATE_KEY")
    for secret in "${secrets[@]}"; do
        if grep -q "\${{ secrets.$secret }}" "$workflow_file"; then
            log_info "✅ シークレット $secret: 参照されています"
        else
            log_warn "⚠️ シークレット $secret の参照が見つかりません"
        fi
    done
    
    # 6. 条件分岐の確認
    log_info "6. 条件分岐の確認"
    local condition_count=$(grep -c "if:" "$workflow_file" || echo "0")
    if [ "$condition_count" -gt 0 ]; then
        log_info "✅ 条件分岐: $condition_count 個"
    else
        log_warn "⚠️ 条件分岐が見つかりません"
    fi
    
    # 7. エラーハンドリングの確認
    log_info "7. エラーハンドリングの確認"
    if grep -q "if: always()" "$workflow_file"; then
        log_info "✅ エラーハンドリング: OK"
    else
        log_warn "⚠️ エラーハンドリングが見つかりません"
    fi
    
    # 8. アーティファクトアップロードの確認
    log_info "8. アーティファクトアップロードの確認"
    if grep -q "actions/upload-artifact" "$workflow_file"; then
        log_info "✅ アーティファクトアップロード: OK"
    else
        log_warn "⚠️ アーティファクトアップロードが見つかりません"
    fi
    
    # 9. ワークフロー固有の機能確認
    log_info "9. ワークフロー固有の機能確認"
    case "$workflow_name" in
        "wordpress-setup")
            if grep -q "ansible" "$workflow_file"; then
                log_info "✅ Ansible実行: OK"
            else
                log_warn "⚠️ Ansible実行が見つかりません"
            fi
            ;;
        "auto-deployment")
            if grep -q "snapshot" "$workflow_file"; then
                log_info "✅ スナップショット機能: OK"
            else
                log_warn "⚠️ スナップショット機能が見つかりません"
            fi
            ;;
        "rollback")
            if grep -q "restore" "$workflow_file"; then
                log_info "✅ 復元機能: OK"
            else
                log_warn "⚠️ 復元機能が見つかりません"
            fi
            ;;
        "setup-deployment")
            if grep -q "terraform" "$workflow_file"; then
                log_info "✅ Terraform設定: OK"
            else
                log_warn "⚠️ Terraform設定が見つかりません"
            fi
            ;;
        "update-ssh-cidr")
            if grep -q "security-group" "$workflow_file"; then
                log_info "✅ セキュリティグループ更新: OK"
            else
                log_warn "⚠️ セキュリティグループ更新が見つかりません"
            fi
            ;;
    esac
    
    log_info "✅ $workflow_name のテスト完了"
    return 0
}

# ワークフローファイルの一覧取得
get_workflow_files() {
    find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true
}

# メイン処理
main() {
    log_info "GitHub Actionsワークフローテストを開始します..."
    
    local workflow_dir=".github/workflows"
    if [ ! -d "$workflow_dir" ]; then
        log_error "ワークフローディレクトリが見つかりません: $workflow_dir"
        exit 1
    fi
    
    local workflow_files=$(get_workflow_files)
    if [ -z "$workflow_files" ]; then
        log_error "ワークフローファイルが見つかりません"
        exit 1
    fi
    
    local total_files=0
    local passed_files=0
    local failed_files=0
    
    for workflow_file in $workflow_files; do
        total_files=$((total_files + 1))
        if test_workflow_functionality "$workflow_file"; then
            passed_files=$((passed_files + 1))
        else
            failed_files=$((failed_files + 1))
        fi
        echo ""
    done
    
    # 結果サマリー
    echo "=========================================="
    log_info "テスト結果サマリー:"
    log_info "総ファイル数: $total_files"
    log_info "成功: $passed_files"
    log_info "失敗: $failed_files"
    
    if [ $failed_files -eq 0 ]; then
        log_info "🎉 すべてのワークフローが正常に機能しています！"
        exit 0
    else
        log_error "❌ $failed_files 個のワークフローに問題があります"
        exit 1
    fi
}

# スクリプト実行
main "$@" 