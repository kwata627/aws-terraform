#!/bin/bash

# =============================================================================
# Terraform設定管理スクリプト
# =============================================================================

# 共通ライブラリの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# =============================================================================
# 定数定義
# =============================================================================

readonly SCRIPT_NAME="Terraform設定管理"
readonly CONFIG_TEMPLATE="$SCRIPT_DIR/../templates/deployment_config.template.json"
readonly TERRAFORM_VARS_FILE="terraform.tfvars"
readonly DEPLOYMENT_CONFIG_FILE="deployment_config.json"

# =============================================================================
# 関数定義
# =============================================================================

# 使用方法の表示
usage() {
    cat << EOF
Terraform設定管理スクリプト

使用方法:
  $0                    # 新規設定ファイル生成
  $0 --update-only      # 既存設定の更新
  $0 --help            # このヘルプを表示

機能:
- ドメイン名の設定
- スナップショット日付の設定
- SSH許可IPの設定
- 検証環境の設定
- 登録者情報の設定
- 既存ドメインの自動検出
- terraform.tfvarsの生成・更新
- deployment_config.jsonの生成・更新

環境変数:
- DOMAIN_NAME: ドメイン名
- SNAPSHOT_DATE: スナップショット日付
- SSH_ALLOWED_IP: SSH許可IP
- VALIDATION_ENABLED: 検証環境有効化 (true/false)
- REGISTRANT_NAME: 登録者名
- REGISTRANT_EMAIL: 登録者メールアドレス
- REGISTRANT_PHONE: 登録者電話番号

EOF
}

# 既存ドメインの検出
check_existing_domain() {
    local domain_name="$1"
    
    # 初期値は新規ドメインとして設定
    local register_domain="true"
    
    # Terraform stateで既存のホストゾーンを確認
    if terraform state list | grep -q "module.route53.aws_route53_zone.main" 2>/dev/null; then
        local existing_domain
        existing_domain=$(terraform state show module.route53.aws_route53_zone.main 2>/dev/null | grep "name" | head -1 | awk '{print $3}' | tr -d '"')
        
        if [ "$existing_domain" = "$domain_name" ]; then
            log_warn "注意: このドメイン名は既にTerraformで管理されています"
            log_warn "既存のホストゾーン: $existing_domain"
            register_domain="false"
        fi
    fi
    
    # Route53でドメイン登録の確認（us-east-1リージョンで確認）
    if command -v aws >/dev/null 2>&1; then
        # AWS CLIでドメイン登録状況を確認
        local domain_exists
        domain_exists=$(aws route53domains list-domains --region us-east-1 --query "Domains[?DomainName=='$domain_name'].DomainName" --output text 2>/dev/null)
        
        if [ "$domain_exists" = "$domain_name" ]; then
            log_warn "注意: このドメインは既にRoute53で登録されています"
            log_warn "ドメイン名: $domain_name"
            register_domain="false"
        else
            log_info "新規ドメインとして検出されました: $domain_name"
            register_domain="true"
        fi
    else
        log_warn "AWS CLIが利用できません。ドメイン登録状況を確認できません。"
        log_warn "手動でドメイン登録状況を確認してください。"
    fi
    
    echo "$register_domain"
}

# 対話的な入力（新規設定時）
interactive_input() {
    echo "=== WordPress AWS環境設定ファイル生成 ==="
    echo ""
    
    # ドメイン名の入力
    log_input "ドメイン名を入力してください (例: example.com): "
    read -p "> " domain_name
    if [ -z "$domain_name" ]; then
        error_exit "ドメイン名は必須です"
    fi
    
    # 既存ドメインの検出
    local register_domain
    register_domain=$(check_existing_domain "$domain_name")
    
    # スナップショット日付の入力
    log_input "スナップショット日付を入力してください (例: 20250803): "
    read -p "> " snapshot_date
    if [ -z "$snapshot_date" ]; then
        error_exit "スナップショット日付は必須です"
    fi
    
    # SSH許可IPの入力
    log_input "SSH許可IPを入力してください (例: 192.168.1.1/32): "
    read -p "> " ssh_allowed_ip
    if [ -z "$ssh_allowed_ip" ]; then
        error_exit "SSH許可IPは必須です"
    fi
    
    # 検証環境の設定
    log_input "検証環境を有効にしますか？ (y/N): "
    read -p "> " validation_enabled
    validation_enabled=${validation_enabled:-N}
    
    # 登録者情報の入力
    log_input "登録者名を入力してください: "
    read -p "> " registrant_name
    if [ -z "$registrant_name" ]; then
        error_exit "登録者名は必須です"
    fi
    
    log_input "登録者メールアドレスを入力してください: "
    read -p "> " registrant_email
    if [ -z "$registrant_email" ]; then
        error_exit "登録者メールアドレスは必須です"
    fi
    
    log_input "登録者電話番号を入力してください (例: +81.1234567890): "
    read -p "> " registrant_phone
    if [ -z "$registrant_phone" ]; then
        error_exit "登録者電話番号は必須です"
    fi
    
    # 設定の保存
    save_config "$domain_name" "$snapshot_date" "$ssh_allowed_ip" "$validation_enabled" "$registrant_name" "$registrant_email" "$registrant_phone" "$register_domain"
}

# 設定の保存
save_config() {
    local domain_name="$1"
    local snapshot_date="$2"
    local ssh_allowed_ip="$3"
    local validation_enabled="$4"
    local registrant_name="$5"
    local registrant_email="$6"
    local registrant_phone="$7"
    local register_domain="$8"
    
    # terraform.tfvarsの生成
    log_step "terraform.tfvarsを生成中..."
    cat > "$TERRAFORM_VARS_FILE" << EOF
# WordPress AWS環境設定
# 生成日時: $(date)

# ドメイン設定
domain_name = "$domain_name"
register_domain = $register_domain

# スナップショット設定
snapshot_date = "$snapshot_date"

# セキュリティ設定
ssh_allowed_ip = "$ssh_allowed_ip"

# 検証環境設定
validation_enabled = $([ "$validation_enabled" = "y" ] && echo "true" || echo "false")

# 登録者情報
registrant_name = "$registrant_name"
registrant_email = "$registrant_email"
registrant_phone = "$registrant_phone"
EOF
    
    log_success "terraform.tfvarsを生成しました"
    
    # deployment_config.jsonの生成
    log_step "deployment_config.jsonを生成中..."
    if [ -f "$CONFIG_TEMPLATE" ]; then
        # テンプレートから環境変数を置換
        envsubst < "$CONFIG_TEMPLATE" > "$DEPLOYMENT_CONFIG_FILE"
        log_success "deployment_config.jsonを生成しました"
    else
        log_warn "テンプレートファイルが見つかりません: $CONFIG_TEMPLATE"
        log_info "手動でdeployment_config.jsonを設定してください"
    fi
    
    # 設定の確認
    log_step "設定内容を確認中..."
    echo ""
    echo "=== 設定内容 ==="
    echo "ドメイン名: $domain_name"
    echo "スナップショット日付: $snapshot_date"
    echo "SSH許可IP: $ssh_allowed_ip"
    echo "検証環境: $([ "$validation_enabled" = "y" ] && echo "有効" || echo "無効")"
    echo "登録者名: $registrant_name"
    echo "登録者メール: $registrant_email"
    echo "登録者電話: $registrant_phone"
    echo "ドメイン登録: $([ "$register_domain" = "true" ] && echo "新規登録" || echo "既存使用")"
    echo ""
    
    # ドメイン登録の確認
    if [ "$register_domain" = "true" ]; then
        log_warn "注意: ドメイン登録には料金が発生します（年間約$12-15）"
        log_input "ドメインを登録しますか？ (y/N): "
        read -p "> " confirm_register
        if [ "$confirm_register" != "y" ]; then
            log_info "ドメイン登録をキャンセルしました"
            # register_domainをfalseに更新
            sed -i 's/register_domain = true/register_domain = false/' "$TERRAFORM_VARS_FILE"
        fi
    fi
    
    log_success "設定ファイルの生成が完了しました"
}

# 既存設定の更新
update_existing_config() {
    log_step "既存設定の更新を開始..."
    
    # 既存ファイルの確認
    if [ ! -f "$TERRAFORM_VARS_FILE" ]; then
        error_exit "既存の設定ファイルが見つかりません: $TERRAFORM_VARS_FILE"
    fi
    
    # バックアップ作成
    create_backup "$TERRAFORM_VARS_FILE"
    
    # 現在の設定を読み込み
    local current_domain
    current_domain=$(grep "^domain_name" "$TERRAFORM_VARS_FILE" | cut -d'"' -f2)
    
    log_info "現在のドメイン: $current_domain"
    
    # 更新項目の確認
    log_input "更新する項目を選択してください:"
    echo "1. SSH許可IP"
    echo "2. 検証環境設定"
    echo "3. 登録者情報"
    echo "4. すべて"
    read -p "選択 (1-4): " update_choice
    
    case "$update_choice" in
        1)
            update_ssh_ip
            ;;
        2)
            update_validation_setting
            ;;
        3)
            update_registrant_info
            ;;
        4)
            update_ssh_ip
            update_validation_setting
            update_registrant_info
            ;;
        *)
            error_exit "無効な選択です"
            ;;
    esac
    
    log_success "設定の更新が完了しました"
}

# SSH許可IPの更新
update_ssh_ip() {
    log_input "新しいSSH許可IPを入力してください: "
    read -p "> " new_ssh_ip
    if [ -z "$new_ssh_ip" ]; then
        error_exit "SSH許可IPは必須です"
    fi
    
    # 設定ファイルの更新
    sed -i "s|ssh_allowed_ip = \".*\"|ssh_allowed_ip = \"$new_ssh_ip\"|" "$TERRAFORM_VARS_FILE"
    log_info "SSH許可IPを更新しました: $new_ssh_ip"
}

# 検証環境設定の更新
update_validation_setting() {
    log_input "検証環境を有効にしますか？ (y/N): "
    read -p "> " new_validation_setting
    new_validation_setting=${new_validation_setting:-N}
    
    local validation_value
    validation_value=$([ "$new_validation_setting" = "y" ] && echo "true" || echo "false")
    
    # 設定ファイルの更新
    sed -i "s|validation_enabled = .*|validation_enabled = $validation_value|" "$TERRAFORM_VARS_FILE"
    log_info "検証環境設定を更新しました: $validation_value"
}

# 登録者情報の更新
update_registrant_info() {
    log_input "新しい登録者名を入力してください: "
    read -p "> " new_name
    if [ -z "$new_name" ]; then
        error_exit "登録者名は必須です"
    fi
    
    log_input "新しい登録者メールアドレスを入力してください: "
    read -p "> " new_email
    if [ -z "$new_email" ]; then
        error_exit "登録者メールアドレスは必須です"
    fi
    
    log_input "新しい登録者電話番号を入力してください: "
    read -p "> " new_phone
    if [ -z "$new_phone" ]; then
        error_exit "登録者電話番号は必須です"
    fi
    
    # 設定ファイルの更新
    sed -i "s|registrant_name = \".*\"|registrant_name = \"$new_name\"|" "$TERRAFORM_VARS_FILE"
    sed -i "s|registrant_email = \".*\"|registrant_email = \"$new_email\"|" "$TERRAFORM_VARS_FILE"
    sed -i "s|registrant_phone = \".*\"|registrant_phone = \"$new_phone\"|" "$TERRAFORM_VARS_FILE"
    
    log_info "登録者情報を更新しました"
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    # 共通初期化
    init_common "$SCRIPT_NAME"
    
    # 引数の解析
    local update_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update-only)
                update_only=true
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
    
    # 作業ディレクトリの確認
    if [ ! -f "main.tf" ]; then
        error_exit "Terraformディレクトリで実行してください"
    fi
    
    # 環境変数からの設定読み込み
    if [ -n "${DOMAIN_NAME:-}" ] && [ -n "${SNAPSHOT_DATE:-}" ] && [ -n "${SSH_ALLOWED_IP:-}" ]; then
        log_info "環境変数から設定を読み込みます"
        local register_domain
        register_domain=$(check_existing_domain "$DOMAIN_NAME")
        
        save_config \
            "$DOMAIN_NAME" \
            "$SNAPSHOT_DATE" \
            "$SSH_ALLOWED_IP" \
            "${VALIDATION_ENABLED:-N}" \
            "${REGISTRANT_NAME:-}" \
            "${REGISTRANT_EMAIL:-}" \
            "${REGISTRANT_PHONE:-}" \
            "$register_domain"
    elif [ "$update_only" = true ]; then
        update_existing_config
    else
        interactive_input
    fi
    
    finish_script "$SCRIPT_NAME" 0
}

# スクリプト実行
main "$@" 