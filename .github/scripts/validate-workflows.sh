#!/bin/bash

# GitHub Actionsワークフロー検証スクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ワークフローファイルの検証
validate_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    log_info "検証中: $workflow_name"
    
    # YAML構文チェック
    if command -v yamllint >/dev/null 2>&1; then
        if yamllint "$workflow_file" >/dev/null 2>&1; then
            log_info "✅ YAML構文: OK"
        else
            log_error "❌ YAML構文エラー"
            yamllint "$workflow_file"
            return 1
        fi
    else
        log_warn "yamllintがインストールされていません。YAML構文チェックをスキップします。"
    fi
    
    # 基本的な構文チェック
    if grep -q "on:" "$workflow_file" && grep -q "jobs:" "$workflow_file"; then
        log_info "✅ 基本的な構造: OK"
    else
        log_error "❌ 基本的な構造エラー: on: または jobs: が見つかりません"
        return 1
    fi
    
    # 必須フィールドのチェック
    local required_fields=("name" "on" "jobs")
    for field in "${required_fields[@]}"; do
        if grep -q "^$field:" "$workflow_file"; then
            log_info "✅ $field: OK"
        else
            log_error "❌ 必須フィールド '$field' が見つかりません"
            return 1
        fi
    done
    
    # アクションのバージョンチェック
    local actions=(
        "actions/checkout@v4"
        "actions/setup-python@v4"
        "aws-actions/configure-aws-credentials@v4"
        "actions/upload-artifact@v4"
    )
    
    for action in "${actions[@]}"; do
        if grep -q "$action" "$workflow_file"; then
            log_info "✅ アクション $action: OK"
        else
            log_warn "⚠️  アクション $action が見つかりません（必須ではない場合があります）"
        fi
    done
    
    # シークレット参照のチェック
    local secrets=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "SSH_PRIVATE_KEY"
        "PRODUCTION_EC2_ID"
        "PRODUCTION_RDS_ID"
    )
    
    for secret in "${secrets[@]}"; do
        if grep -q "\${{ secrets.$secret }}" "$workflow_file"; then
            log_info "✅ シークレット $secret: 参照されています"
        else
            log_warn "⚠️  シークレット $secret の参照が見つかりません"
        fi
    done
    
    log_info "✅ $workflow_name の検証完了"
    return 0
}

# ワークフローファイルの一覧取得
get_workflow_files() {
    find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true
}

# メイン処理
main() {
    log_info "GitHub Actionsワークフロー検証を開始します..."
    
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
        if validate_workflow "$workflow_file"; then
            passed_files=$((passed_files + 1))
        else
            failed_files=$((failed_files + 1))
        fi
        echo ""
    done
    
    # 結果サマリー
    echo "=========================================="
    log_info "検証結果サマリー:"
    log_info "総ファイル数: $total_files"
    log_info "成功: $passed_files"
    log_info "失敗: $failed_files"
    
    if [ $failed_files -eq 0 ]; then
        log_info "🎉 すべてのワークフローが正常です！"
        exit 0
    else
        log_error "❌ $failed_files 個のワークフローに問題があります"
        exit 1
    fi
}

# スクリプト実行
main "$@" 