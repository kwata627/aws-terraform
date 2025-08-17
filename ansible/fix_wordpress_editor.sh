#!/bin/bash

# =============================================================================
# WordPressエディタ修正スクリプト
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# 環境変数の読み込み
source "$SCRIPT_DIR/load_env.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="WordPressエディタ修正"
readonly PLAYBOOK="playbooks/fix_wordpress_editor.yml"
readonly INVENTORY="inventory/hosts.yml"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
WordPressエディタ修正スクリプト

WordPressの管理画面でエディタがブロックされる問題を修正します。

使用方法:
  $0                                    # デフォルト設定で実行
  $0 --dry-run                          # ドライラン実行
  $0 --help                            # このヘルプを表示

問題の原因:
- Content Security Policy (CSP) ヘッダーがWordPress.orgドメインを許可していない
- WordPressブロックエディタ（Gutenberg）が正常に動作するために必要なリソースがブロックされている

修正内容:
- WordPress.orgドメインの許可
- API接続の許可
- エディタ用アセットの許可
- 管理画面専用のCSP設定追加

例:
  $0 --dry-run
  $0

EOF
}

# メイン処理
main() {
    # 引数の解析
    local dry_run="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "=== $SCRIPT_NAME 開始 ==="
    log_info "プレイブック: $PLAYBOOK"
    log_info "ドライラン: $dry_run"
    
    # 前提条件チェック
    init_ansible_common "$SCRIPT_NAME"
    
    # インベントリの確認
    check_inventory "$INVENTORY"
    
    # プレイブックの確認
    check_playbook "$PLAYBOOK"
    
    # 接続テスト
    if ! test_connection "$INVENTORY" "wordpress"; then
        log_warn "接続テストに失敗しましたが、処理を続行します"
    fi
    
    # プレイブック実行
    if ! run_playbook "$PLAYBOOK" "$INVENTORY" "$dry_run" "false"; then
        log_error "プレイブックの実行に失敗しました"
        exit 1
    fi
    
    log_success "=== $SCRIPT_NAME 完了 ==="
    echo ""
    echo "WordPressエディタの修正が完了しました"
    echo "管理画面にアクセスしてエディタが正常に動作するか確認してください"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
