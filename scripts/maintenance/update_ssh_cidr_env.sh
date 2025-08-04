#!/bin/bash

# =============================================================================
# SSH許可IP更新スクリプト
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="SSH許可IP更新"
readonly TERRAFORM_VARS_FILE="terraform.tfvars"
readonly CONFIG_FILE="deployment_config.json"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
SSH許可IP更新スクリプト

使用方法:
  $0                                    # 環境変数からIPを取得して更新
  $0 --ip <IP_ADDRESS>                  # 指定したIPで更新
  $0 --cidr <CIDR_RANGE>                # 指定したCIDRで更新
  $0 --help                            # このヘルプを表示

機能:
- SSH許可IPの更新
- Terraform設定ファイルの更新
- 設定の検証
- バックアップ作成

環境変数:
- SSH_ALLOWED_IP: SSH許可IPアドレス
- AWS_REGION: AWSリージョン (デフォルト: ap-northeast-1)
- AWS_PROFILE: AWSプロファイル (デフォルト: default)

例:
  export SSH_ALLOWED_IP=192.168.1.100
  $0

  $0 --ip 192.168.1.100

  $0 --cidr 192.168.1.0/24

EOF
}

# IPアドレスの検証
validate_ip_address() {
    local ip="$1"
    
    # IPv4アドレスの形式チェック
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error_exit "無効なIPアドレス形式です: $ip"
    fi
    
    # 各オクテットの値チェック
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            error_exit "無効なIPアドレス値です: $ip"
        fi
    done
    
    log_info "IPアドレスを検証しました: $ip"
}

# CIDR形式の検証
validate_cidr() {
    local cidr="$1"
    
    # CIDR形式のチェック
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        error_exit "無効なCIDR形式です: $cidr"
    fi
    
    # IPアドレス部分の検証
    local ip_part
    ip_part=$(echo "$cidr" | cut -d'/' -f1)
    validate_ip_address "$ip_part"
    
    # サブネットマスク部分の検証
    local mask_part
    mask_part=$(echo "$cidr" | cut -d'/' -f2)
    if [ "$mask_part" -lt 0 ] || [ "$mask_part" -gt 32 ]; then
        error_exit "無効なサブネットマスクです: $mask_part"
    fi
    
    log_info "CIDR形式を検証しました: $cidr"
}

# IPアドレスをCIDR形式に変換
convert_ip_to_cidr() {
    local ip="$1"
    validate_ip_address "$ip"
    echo "${ip}/32"
}

# 設定ファイルの更新
update_terraform_config() {
    local new_cidr="$1"
    
    log_step "Terraform設定ファイルを更新中..."
    
    # 設定ファイルの存在確認
    if [ ! -f "$TERRAFORM_VARS_FILE" ]; then
        error_exit "Terraform設定ファイルが見つかりません: $TERRAFORM_VARS_FILE"
    fi
    
    # バックアップ作成
    create_backup "$TERRAFORM_VARS_FILE"
    
    # 設定ファイルの更新
    if grep -q "^ssh_allowed_ip" "$TERRAFORM_VARS_FILE"; then
        # 既存の設定を更新
        sed -i "s|ssh_allowed_ip = \".*\"|ssh_allowed_ip = \"$new_cidr\"|" "$TERRAFORM_VARS_FILE"
        log_info "既存のSSH許可IP設定を更新しました"
    else
        # 新しい設定を追加
        echo "" >> "$TERRAFORM_VARS_FILE"
        echo "# SSH接続許可IP（セキュリティ強化）" >> "$TERRAFORM_VARS_FILE"
        echo "ssh_allowed_ip = \"$new_cidr\"" >> "$TERRAFORM_VARS_FILE"
        log_info "新しいSSH許可IP設定を追加しました"
    fi
    
    log_success "Terraform設定ファイルを更新しました: $new_cidr"
}

# デプロイメント設定ファイルの更新
update_deployment_config() {
    local new_cidr="$1"
    
    if [ -f "$CONFIG_FILE" ]; then
        log_step "デプロイメント設定ファイルを更新中..."
        
        # バックアップ作成
        create_backup "$CONFIG_FILE"
        
        # 設定の更新
        update_config "$CONFIG_FILE" ".security.ssh_allowed_ip" "$new_cidr"
        
        log_success "デプロイメント設定ファイルを更新しました"
    else
        log_warn "デプロイメント設定ファイルが見つかりません: $CONFIG_FILE"
    fi
}

# Terraform planの実行
run_terraform_plan() {
    log_step "Terraform planを実行中..."
    
    # Terraformの初期化確認
    if [ ! -f ".terraform/terraform.tfstate" ]; then
        log_info "Terraformを初期化中..."
        terraform init
    fi
    
    # Terraform planの実行
    if terraform plan -var-file="$TERRAFORM_VARS_FILE" -detailed-exitcode; then
        log_success "Terraform planが正常に完了しました"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 2 ]; then
            log_warn "Terraform planで変更が検出されました"
            return 0
        else
            error_exit "Terraform planでエラーが発生しました"
        fi
    fi
}

# 変更内容の確認
confirm_changes() {
    local new_cidr="$1"
    
    log_step "変更内容を確認中..."
    
    echo ""
    echo "=== 変更内容 ==="
    echo "新しいSSH許可IP: $new_cidr"
    echo ""
    
    # 現在の設定を表示
    if [ -f "$TERRAFORM_VARS_FILE" ]; then
        local current_ip
        current_ip=$(grep "^ssh_allowed_ip" "$TERRAFORM_VARS_FILE" | cut -d'"' -f2 2>/dev/null || echo "未設定")
        echo "現在のSSH許可IP: $current_ip"
    fi
    
    echo ""
    log_input "この変更を適用しますか？ (y/N): "
    read -p "> " confirm
    if [ "$confirm" != "y" ]; then
        log_info "変更をキャンセルしました"
        exit 0
    fi
}

# セキュリティ警告の表示
show_security_warning() {
    local cidr="$1"
    
    # 0.0.0.0/0の場合の警告
    if [ "$cidr" = "0.0.0.0/0" ]; then
        log_warn "⚠️  警告: すべてのIPからのアクセスを許可しています"
        log_warn "本番環境では特定のIPに制限することを強く推奨します"
        echo ""
    fi
    
    # プライベートIPレンジの場合の確認
    if [[ "$cidr" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
        log_info "プライベートIPレンジが設定されています: $cidr"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    # 共通初期化
    init_common "$SCRIPT_NAME"
    
    # 引数の解析
    local new_ip=""
    local new_cidr=""
    local auto_confirm=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ip)
                new_ip="$2"
                shift 2
                ;;
            --cidr)
                new_cidr="$2"
                shift 2
                ;;
            --auto-confirm)
                auto_confirm=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error_exit "不明なオプション: $1"
                ;;
        esac
    done
    
    # IPアドレスの決定
    if [ -n "$new_cidr" ]; then
        # CIDR形式が指定された場合
        validate_cidr "$new_cidr"
        final_cidr="$new_cidr"
    elif [ -n "$new_ip" ]; then
        # IPアドレスが指定された場合
        final_cidr=$(convert_ip_to_cidr "$new_ip")
    elif [ -n "${SSH_ALLOWED_IP:-}" ]; then
        # 環境変数から取得
        if [[ "$SSH_ALLOWED_IP" =~ /[0-9]{1,2}$ ]]; then
            # CIDR形式の場合
            validate_cidr "$SSH_ALLOWED_IP"
            final_cidr="$SSH_ALLOWED_IP"
        else
            # IPアドレスの場合
            final_cidr=$(convert_ip_to_cidr "$SSH_ALLOWED_IP")
        fi
    else
        error_exit "SSH許可IPが指定されていません。環境変数SSH_ALLOWED_IPを設定するか、--ipまたは--cidrオプションを使用してください"
    fi
    
    # セキュリティ警告の表示
    show_security_warning "$final_cidr"
    
    # 変更内容の確認（自動確認でない場合）
    if [ "$auto_confirm" != true ]; then
        confirm_changes "$final_cidr"
    fi
    
    # 設定ファイルの更新
    update_terraform_config "$final_cidr"
    update_deployment_config "$final_cidr"
    
    # Terraform planの実行
    run_terraform_plan
    
    log_success "SSH許可IPの更新が完了しました: $final_cidr"
    
    # 適用の確認
    if [ "$auto_confirm" != true ]; then
        log_input "Terraform applyを実行しますか？ (y/N): "
        read -p "> " apply_confirm
        if [ "$apply_confirm" = "y" ]; then
            log_step "Terraform applyを実行中..."
            terraform apply -var-file="$TERRAFORM_VARS_FILE" -auto-approve
            log_success "Terraform applyが完了しました"
        else
            log_info "Terraform applyをスキップしました"
        fi
    fi
    
    finish_script "$SCRIPT_NAME" 0
}

# スクリプト実行
main "$@" 