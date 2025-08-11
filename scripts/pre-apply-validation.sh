#!/bin/bash

# Terraform apply実行前の自動検証スクリプト
# SSL設定の問題を事前に検出・修正

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_SCRIPT="$SCRIPT_DIR/validate-ssl-setup.sh"

# 色付きログ関数
log() {
    echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m"
}

success() {
    echo -e "\033[1;32m[SUCCESS] $1\033[0m"
}

# メイン処理
main() {
    log "=== Terraform事前検証開始 ==="
    
    # SSL設定の自動検証・修正を実行
    if [ -f "$VALIDATION_SCRIPT" ]; then
        log "SSL設定の自動検証・修正を実行中..."
        "$VALIDATION_SCRIPT"
        
        if [ $? -eq 0 ]; then
            success "SSL設定の検証・修正が完了しました"
        else
            error "SSL設定の検証・修正で問題が発生しました"
            exit 1
        fi
    else
        error "検証スクリプトが見つかりません: $VALIDATION_SCRIPT"
        exit 1
    fi
    
    log "=== Terraform事前検証完了 ==="
}

# スクリプト実行
main "$@"
