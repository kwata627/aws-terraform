#!/bin/bash

# =============================================================================
# Domain Analysis Test Script
# =============================================================================
# 
# このスクリプトは、ドメイン分析機能をテストします。
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
Domain Analysis Test Script

使用方法:
    $0 [オプション] <ドメイン名>

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力
    -t, --terraform     Terraformモードでテスト

例:
    $0 example.com                    # 基本的なテスト
    $0 -v example.com                 # 詳細出力
    $0 -t example.com                 # Terraformモード

EOF
}

# デフォルト値
VERBOSE=false
TERRAFORM_MODE=false

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
        -t|--terraform)
            TERRAFORM_MODE=true
            shift
            ;;
        -*)
            error "不明なオプション: $1"
            show_help
            exit 1
            ;;
        *)
            DOMAIN_NAME="$1"
            shift
            ;;
    esac
done

# ドメイン名の確認
if [ -z "$DOMAIN_NAME" ]; then
    error "ドメイン名を指定してください"
    show_help
    exit 1
fi

# ドメイン名の正規化
DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr '[:upper:]' '[:lower:]')

# テスト実行
main() {
    log "=== ドメイン分析テスト開始 ==="
    echo "対象ドメイン: $DOMAIN_NAME"
    echo "Terraformモード: $TERRAFORM_MODE"
    echo "詳細出力: $VERBOSE"
    echo
    
    # スクリプトの存在確認
    if [ ! -f "scripts/check_nameservers.sh" ]; then
        error "scripts/check_nameservers.sh が見つかりません"
        exit 1
    fi
    
    # 実行権限の確認
    if [ ! -x "scripts/check_nameservers.sh" ]; then
        log "実行権限を付与中..."
        chmod +x scripts/check_nameservers.sh
    fi
    
    # コマンド構築
    CMD="scripts/check_nameservers.sh -d $DOMAIN_NAME"
    
    if [ "$VERBOSE" = true ]; then
        CMD="$CMD -v"
    fi
    
    if [ "$TERRAFORM_MODE" = true ]; then
        CMD="$CMD -t"
        export TERRAFORM_MODE=true
    fi
    
    # スクリプト実行
    log "コマンド実行: $CMD"
    echo
    
    # 実行結果をキャプチャ
    if [ "$TERRAFORM_MODE" = true ]; then
        # Terraformモードの場合はJSON出力を解析
        RESULT=$(eval $CMD 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            success "スクリプトが正常に実行されました"
            echo
            echo "JSON出力:"
            echo "$RESULT" | jq '.' 2>/dev/null || echo "$RESULT"
            echo
            
            # JSONを解析して結果を表示
            if command -v jq &> /dev/null; then
                echo "解析結果:"
                echo "  ドメイン名: $(echo "$RESULT" | jq -r '.domain_name')"
                echo "  Route53存在: $(echo "$RESULT" | jq -r '.domain_exists_in_route53')"
                echo "  DNS存在: $(echo "$RESULT" | jq -r '.domain_exists_in_dns')"
                echo "  登録済み: $(echo "$RESULT" | jq -r '.domain_registered')"
                echo "  既存ゾーン使用: $(echo "$RESULT" | jq -r '.should_use_existing')"
                echo "  ドメイン登録: $(echo "$RESULT" | jq -r '.should_register_domain')"
            fi
        else
            error "スクリプトの実行に失敗しました"
            exit 1
        fi
    else
        # 通常モードの場合は直接実行
        eval $CMD
        
        if [ $? -eq 0 ]; then
            success "スクリプトが正常に実行されました"
        else
            error "スクリプトの実行に失敗しました"
            exit 1
        fi
    fi
    
    echo
    log "=== ドメイン分析テスト完了 ==="
}

# スクリプト実行
main "$@"
