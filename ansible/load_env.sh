#!/bin/bash

# =============================================================================
# 環境変数読み込みスクリプト
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# デフォルトの環境変数ファイル
ENV_FILE="${SCRIPT_DIR}/.env"

# 環境変数ファイルが存在する場合、読み込み
if [ -f "$ENV_FILE" ]; then
    echo "環境変数ファイルを読み込み中: $ENV_FILE"
    source "$ENV_FILE"
else
    echo "環境変数ファイルが見つかりません: $ENV_FILE"
    echo "templates/env.template をコピーして .env ファイルを作成してください"
    echo "例: cp templates/env.template .env"
fi

# 必須環境変数の確認
check_required_env_vars() {
    local required_vars=(
        "WORDPRESS_DB_HOST"
        "WORDPRESS_DB_USER"
        "WORDPRESS_DB_PASSWORD"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "警告: 以下の環境変数が設定されていません:"
        printf '  - %s\n' "${missing_vars[@]}"
        echo "templates/env.template を参考に .env ファイルを設定してください"
        return 1
    fi
    
    echo "環境変数の設定を確認しました"
    return 0
}

# 環境変数の表示（デバッグ用）
show_env_vars() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "=== 環境変数一覧 ==="
        env | grep -E "^(WORDPRESS_|SSH_|PHP_|MONITORING_)" | sort
        echo "===================="
    fi
}

# メイン処理
main() {
    check_required_env_vars
    show_env_vars
}

# スクリプトが直接実行された場合のみ実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
