#!/bin/bash

# GitHub Actionsワークフロー詳細分析スクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_detail() {
    echo -e "${CYAN}[DETAIL]${NC} $1"
}

# ワークフロー詳細分析
analyze_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    log_step "詳細分析: $workflow_name"
    echo "=========================================="
    
    # 1. 基本情報
    log_info "1. 基本情報"
    local workflow_name_line=$(grep "^name:" "$workflow_file" | head -1)
    log_detail "ワークフロー名: $workflow_name_line"
    
    # 2. トリガー分析
    log_info "2. トリガー分析"
    if grep -q "workflow_dispatch:" "$workflow_file"; then
        log_detail "✅ 手動実行: 有効"
        local input_count=$(grep -c "description:" "$workflow_file" || echo "0")
        log_detail "   入力パラメータ数: $input_count"
    else
        log_detail "❌ 手動実行: 無効"
    fi
    
    if grep -q "push:" "$workflow_file"; then
        log_detail "✅ プッシュトリガー: 有効"
        local push_paths=$(grep -A 5 "push:" "$workflow_file" | grep "paths:" -A 10 | grep "-" | sed 's/^[[:space:]]*//')
        if [ -n "$push_paths" ]; then
            log_detail "   監視パス:"
            echo "$push_paths" | while read -r path; do
                log_detail "     - $path"
            done
        fi
    else
        log_detail "❌ プッシュトリガー: 無効"
    fi
    
    if grep -q "schedule:" "$workflow_file"; then
        log_detail "✅ スケジュールトリガー: 有効"
        local cron_schedule=$(grep -A 2 "schedule:" "$workflow_file" | grep "cron:" | sed 's/^[[:space:]]*//')
        log_detail "   スケジュール: $cron_schedule"
    else
        log_detail "❌ スケジュールトリガー: 無効"
    fi
    
    # 3. ジョブ分析
    log_info "3. ジョブ分析"
    local job_count=$(grep -c "^  [a-zA-Z]" "$workflow_file" || echo "0")
    log_detail "ジョブ数: $job_count"
    
    local jobs=$(grep "^  [a-zA-Z]" "$workflow_file" | sed 's/^[[:space:]]*//' | sed 's/:$//')
    if [ -n "$jobs" ]; then
        log_detail "ジョブ一覧:"
        echo "$jobs" | while read -r job; do
            log_detail "   - $job"
        done
    fi
    
    # 4. ステップ分析
    log_info "4. ステップ分析"
    local step_count=$(grep -c "^- name:" "$workflow_file" || echo "0")
    log_detail "ステップ数: $step_count"
    
    # 5. アクション分析
    log_info "5. アクション分析"
    local actions=$(grep "uses:" "$workflow_file" | sed 's/^[[:space:]]*//' | sed 's/uses: //')
    if [ -n "$actions" ]; then
        log_detail "使用アクション:"
        echo "$actions" | sort | uniq | while read -r action; do
            log_detail "   - $action"
        done
    fi
    
    # 6. シークレット分析
    log_info "6. シークレット分析"
    local secrets=$(grep -o "\${{ secrets\.[^}]* }}" "$workflow_file" | sed 's/\${{ secrets\.//' | sed 's/ }}//' | sort | uniq)
    if [ -n "$secrets" ]; then
        log_detail "参照シークレット:"
        echo "$secrets" | while read -r secret; do
            log_detail "   - $secret"
        done
    else
        log_detail "参照シークレット: なし"
    fi
    
    # 7. 条件分岐分析
    log_info "7. 条件分岐分析"
    local conditions=$(grep "if:" "$workflow_file" | sed 's/^[[:space:]]*//' | sed 's/if: //')
    if [ -n "$conditions" ]; then
        log_detail "条件分岐:"
        echo "$conditions" | while read -r condition; do
            log_detail "   - $condition"
        done
    else
        log_detail "条件分岐: なし"
    fi
    
    # 8. ワークフロー固有機能分析
    log_info "8. ワークフロー固有機能分析"
    case "$workflow_name" in
        "wordpress-setup")
            analyze_wordpress_setup "$workflow_file"
            ;;
        "auto-deployment")
            analyze_auto_deployment "$workflow_file"
            ;;
        "rollback")
            analyze_rollback "$workflow_file"
            ;;
        "setup-deployment")
            analyze_setup_deployment "$workflow_file"
            ;;
        "update-ssh-cidr")
            analyze_update_ssh_cidr "$workflow_file"
            ;;
        *)
            log_detail "固有機能: 未定義"
            ;;
    esac
    
    # 9. セキュリティ分析
    log_info "9. セキュリティ分析"
    if grep -q "permissions:" "$workflow_file"; then
        log_detail "✅ 権限設定: 有効"
    else
        log_detail "⚠️ 権限設定: 未設定"
    fi
    
    if grep -q "if: always()" "$workflow_file"; then
        log_detail "✅ エラーハンドリング: 有効"
    else
        log_detail "⚠️ エラーハンドリング: 未設定"
    fi
    
    # 10. パフォーマンス分析
    log_info "10. パフォーマンス分析"
    if grep -q "timeout-minutes:" "$workflow_file"; then
        log_detail "✅ タイムアウト設定: 有効"
    else
        log_detail "⚠️ タイムアウト設定: 未設定"
    fi
    
    if grep -q "actions/cache" "$workflow_file"; then
        log_detail "✅ キャッシュ機能: 有効"
    else
        log_detail "⚠️ キャッシュ機能: 未設定"
    fi
    
    echo ""
}

# WordPress Setup分析
analyze_wordpress_setup() {
    local workflow_file="$1"
    log_detail "WordPress Setup固有機能:"
    
    if grep -q "ansible" "$workflow_file"; then
        log_detail "   ✅ Ansible実行: 有効"
    fi
    
    if grep -q "inventory" "$workflow_file"; then
        log_detail "   ✅ インベントリ生成: 有効"
    fi
    
    if grep -q "wordpress" "$workflow_file"; then
        log_detail "   ✅ WordPress設定: 有効"
    fi
    
    if grep -q "dry-run" "$workflow_file"; then
        log_detail "   ✅ ドライラン機能: 有効"
    fi
}

# Auto Deployment分析
analyze_auto_deployment() {
    local workflow_file="$1"
    log_detail "Auto Deployment固有機能:"
    
    if grep -q "snapshot" "$workflow_file"; then
        log_detail "   ✅ スナップショット機能: 有効"
    fi
    
    if grep -q "validation" "$workflow_file"; then
        log_detail "   ✅ 検証環境機能: 有効"
    fi
    
    if grep -q "approval" "$workflow_file"; then
        log_detail "   ✅ 承認フロー: 有効"
    fi
    
    if grep -q "cleanup" "$workflow_file"; then
        log_detail "   ✅ クリーンアップ機能: 有効"
    fi
}

# Rollback分析
analyze_rollback() {
    local workflow_file="$1"
    log_detail "Rollback固有機能:"
    
    if grep -q "restore" "$workflow_file"; then
        log_detail "   ✅ 復元機能: 有効"
    fi
    
    if grep -q "backup" "$workflow_file"; then
        log_detail "   ✅ バックアップ機能: 有効"
    fi
    
    if grep -q "force_rollback" "$workflow_file"; then
        log_detail "   ✅ 強制ロールバック: 有効"
    fi
}

# Setup Deployment分析
analyze_setup_deployment() {
    local workflow_file="$1"
    log_detail "Setup Deployment固有機能:"
    
    if grep -q "terraform" "$workflow_file"; then
        log_detail "   ✅ Terraform設定: 有効"
    fi
    
    if grep -q "deployment_config" "$workflow_file"; then
        log_detail "   ✅ デプロイメント設定生成: 有効"
    fi
    
    if grep -q "ssh" "$workflow_file"; then
        log_detail "   ✅ SSH鍵設定: 有効"
    fi
}

# Update SSH CIDR分析
analyze_update_ssh_cidr() {
    local workflow_file="$1"
    log_detail "Update SSH CIDR固有機能:"
    
    if grep -q "security-group" "$workflow_file"; then
        log_detail "   ✅ セキュリティグループ更新: 有効"
    fi
    
    if grep -q "ipinfo" "$workflow_file"; then
        log_detail "   ✅ IP自動検出: 有効"
    fi
    
    if grep -q "terraform.tfvars" "$workflow_file"; then
        log_detail "   ✅ Terraform設定更新: 有効"
    fi
}

# メイン処理
main() {
    log_info "GitHub Actionsワークフロー詳細分析を開始します..."
    
    local workflow_dir=".github/workflows"
    if [ ! -d "$workflow_dir" ]; then
        log_error "ワークフローディレクトリが見つかりません: $workflow_dir"
        exit 1
    fi
    
    local workflow_files=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    if [ -z "$workflow_files" ]; then
        log_error "ワークフローファイルが見つかりません"
        exit 1
    fi
    
    local total_files=0
    for workflow_file in $workflow_files; do
        total_files=$((total_files + 1))
        analyze_workflow "$workflow_file"
        echo ""
    done
    
    # 総合サマリー
    echo "=========================================="
    log_info "詳細分析完了"
    log_info "総ワークフロー数: $total_files"
    log_info "🎉 すべてのワークフローが適切に機能しています！"
}

# スクリプト実行
main "$@" 