#!/bin/bash

# =============================================================================
# Safe Route53 Cleanup Script
# =============================================================================
# 
# このスクリプトは、Route53ホストゾーンを安全に削除します。
# 削除前にレコードの確認とバックアップを行います。
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
Safe Route53 Cleanup Script

使用方法:
    $0 [オプション] <ホストゾーンID>

オプション:
    -h, --help          このヘルプを表示
    -f, --force         確認なしで削除
    -b, --backup        バックアップを作成
    -d, --dry-run       実際の削除は行わず、確認のみ

例:
    $0 Z0031614DJ701EV9ZQ26                    # 基本的な削除
    $0 -f Z0031614DJ701EV9ZQ26                 # 強制削除
    $0 -b -d Z0031614DJ701EV9ZQ26              # バックアップ作成とドライラン

EOF
}

# デフォルト値
FORCE=false
BACKUP=false
DRY_RUN=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            error "不明なオプション: $1"
            show_help
            exit 1
            ;;
        *)
            ZONE_ID="$1"
            shift
            ;;
    esac
done

# ホストゾーンIDの確認
if [ -z "$ZONE_ID" ]; then
    error "ホストゾーンIDを指定してください"
    show_help
    exit 1
fi

# ホストゾーンIDの正規化（/hostedzone/プレフィックスを削除）
ZONE_ID=$(echo "$ZONE_ID" | sed 's|^/hostedzone/||')

# バックアップディレクトリの作成
BACKUP_DIR="backups/route53/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# ホストゾーン情報の取得
get_zone_info() {
    log "ホストゾーン情報を取得中..."
    
    # Terraformの状態から情報を取得
    local zone_info=$(terraform state show "module.route53.aws_route53_zone.main[0]" 2>/dev/null || echo "")
    
    if [ -n "$zone_info" ]; then
        success "Terraform状態からホストゾーン情報を取得しました"
        echo "$zone_info" > "$BACKUP_DIR/zone_info.txt"
        
        # ゾーン名を抽出
        ZONE_NAME=$(echo "$zone_info" | grep "name" | head -1 | awk '{print $3}' | tr -d '"')
        echo "ゾーン名: $ZONE_NAME"
    else
        warning "Terraform状態からホストゾーン情報を取得できませんでした"
        ZONE_NAME="unknown"
    fi
}

# レコードの確認
check_records() {
    log "ホストゾーン内のレコードを確認中..."
    
    # Terraformの状態からレコードを確認
    local records=$(terraform state list | grep "route53.*record" | grep -v "certificate_validation" || echo "")
    
    if [ -n "$records" ]; then
        warning "以下のレコードが存在します:"
        echo "$records" | while read -r record; do
            echo "  - $record"
        done
        
        # レコードの詳細を取得
        echo "$records" | while read -r record; do
            if [ -n "$record" ]; then
                terraform state show "$record" > "$BACKUP_DIR/record_$(echo $record | sed 's/[^a-zA-Z0-9]/_/g').txt" 2>/dev/null || true
            fi
        done
    else
        success "削除可能なレコードは見つかりませんでした"
    fi
    
    # ACM証明書検証レコードの確認
    local cert_records=$(terraform state list | grep "certificate_validation" || echo "")
    if [ -n "$cert_records" ]; then
        warning "ACM証明書検証レコードが存在します:"
        echo "$cert_records" | while read -r record; do
            echo "  - $record"
        done
    fi
}

# バックアップの作成
create_backup() {
    if [ "$BACKUP" = true ]; then
        log "バックアップを作成中..."
        
        # Terraform状態のバックアップ
        terraform state pull > "$BACKUP_DIR/terraform_state.json"
        
        # 設定ファイルのバックアップ
        cp terraform.tfvars "$BACKUP_DIR/" 2>/dev/null || true
        cp main.tf "$BACKUP_DIR/" 2>/dev/null || true
        
        success "バックアップが作成されました: $BACKUP_DIR"
    fi
}

# 削除の実行
execute_deletion() {
    if [ "$DRY_RUN" = true ]; then
        log "ドライラン: 削除は実行されません"
        echo "削除対象:"
        echo "  - ホストゾーン: $ZONE_ID"
        echo "  - ゾーン名: $ZONE_NAME"
        return 0
    fi
    
    log "Route53ホストゾーンの削除を開始..."
    
    # Terraformで削除
    if terraform destroy -target="module.route53.aws_route53_zone.main[0]" -auto-approve; then
        success "Route53ホストゾーンの削除が完了しました"
    else
        error "Route53ホストゾーンの削除に失敗しました"
        return 1
    fi
}

# 確認プロンプト
confirm_deletion() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo
    warning "以下のホストゾーンを削除しようとしています:"
    echo "  ホストゾーンID: $ZONE_ID"
    echo "  ゾーン名: $ZONE_NAME"
    echo
    
    echo -n "本当に削除しますか？ (yes/no): "
    read CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "削除をキャンセルしました"
        exit 0
    fi
}

# メイン処理
main() {
    log "=== Route53ホストゾーン削除開始 ==="
    echo "ホストゾーンID: $ZONE_ID"
    echo "強制削除: $FORCE"
    echo "バックアップ: $BACKUP"
    echo "ドライラン: $DRY_RUN"
    echo
    
    # ホストゾーン情報の取得
    get_zone_info
    
    # レコードの確認
    check_records
    
    # バックアップの作成
    create_backup
    
    # 確認プロンプト
    confirm_deletion
    
    # 削除の実行
    execute_deletion
    
    log "=== Route53ホストゾーン削除完了 ==="
}

# スクリプト実行
main "$@"
