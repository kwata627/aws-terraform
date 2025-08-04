#!/bin/bash

# Terraform設定管理スクリプト
# 使用方法: ./terraform_config.sh [--update-only]

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

log_input() {
    echo -e "\033[36m[INPUT]\033[0m $1"
}

# 使用方法の表示
usage() {
    echo "Terraform設定管理スクリプト"
    echo ""
    echo "使用方法:"
    echo "  $0                    # 新規設定ファイル生成"
    echo "  $0 --update-only      # 既存設定の更新"
    echo ""
    echo "機能:"
    echo "- ドメイン名の設定"
    echo "- スナップショット日付の設定"
    echo "- SSH許可IPの設定"
    echo "- 検証環境の設定"
    echo "- 登録者情報の設定"
    echo "- 既存ドメインの自動検出"
    echo "- terraform.tfvarsの生成・更新"
}

# 既存ドメインの検出
check_existing_domain() {
    local domain_name=$1
    
    # 初期値は新規ドメインとして設定
    register_domain="true"
    
    # Terraform stateで既存のホストゾーンを確認
    if terraform state list | grep -q "module.route53.aws_route53_zone.main"; then
        local existing_domain=$(terraform state show module.route53.aws_route53_zone.main 2>/dev/null | grep "name" | head -1 | awk '{print $3}' | tr -d '"')
        
        if [ "$existing_domain" = "$domain_name" ]; then
            log_warn "注意: このドメイン名は既にTerraformで管理されています"
            log_warn "既存のホストゾーン: $existing_domain"
            register_domain="false"
        fi
    fi
    
    # Route53でドメイン登録の確認（us-east-1リージョンで確認）
    if command -v aws >/dev/null 2>&1; then
        # AWS CLIでドメイン登録状況を確認
        local domain_exists=$(aws route53domains list-domains --region us-east-1 --query "Domains[?DomainName=='$domain_name'].DomainName" --output text 2>/dev/null)
        
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
}

# 対話的な入力（新規設定時）
interactive_input() {
    echo "=== WordPress AWS環境設定ファイル生成 ==="
    echo ""
    
    # ドメイン名の入力
    log_input "ドメイン名を入力してください (例: example.com): "
    read -p "> " domain_name
    if [ -z "$domain_name" ]; then
        log_error "ドメイン名は必須です"
        exit 1
    fi
    
    # 既存ドメインの検出
    check_existing_domain "$domain_name"
    
    # スナップショット日付の入力
    log_input "スナップショット日付を入力してください (例: 20250803): "
    read -p "> " snapshot_date
    if [ -z "$snapshot_date" ]; then
        log_error "スナップショット日付は必須です"
        exit 1
    fi
    
    # SSH許可IPの入力
    log_input "SSH許可IPを入力してください (デフォルト: 0.0.0.0/0): "
    read -p "> " ssh_allowed_cidr
    ssh_allowed_cidr=${ssh_allowed_cidr:-"0.0.0.0/0"}
    
    # 検証環境の設定
    log_input "検証用EC2を有効にしますか？ (y/N): "
    read -p "> " enable_validation_ec2_input
    if [ "$enable_validation_ec2_input" = "y" ] || [ "$enable_validation_ec2_input" = "Y" ]; then
        enable_validation_ec2="true"
    else
        enable_validation_ec2="false"
    fi
    
    log_input "検証用RDSを有効にしますか？ (y/N): "
    read -p "> " enable_validation_rds_input
    if [ "$enable_validation_rds_input" = "y" ] || [ "$enable_validation_rds_input" = "Y" ]; then
        enable_validation_rds="true"
    else
        enable_validation_rds="false"
    fi
    
    # 登録者情報の入力
    echo ""
    log_info "ドメイン登録者情報を入力してください"
    echo ""
    
    log_input "姓を入力してください: "
    read -p "> " first_name
    first_name=${first_name:-"Admin"}
    
    log_input "名を入力してください: "
    read -p "> " last_name
    last_name=${last_name:-"User"}
    
    log_input "組織名を入力してください: "
    read -p "> " organization_name
    organization_name=${organization_name:-"My Organization"}
    
    log_input "メールアドレスを入力してください: "
    read -p "> " email
    email=${email:-"admin@example.com"}
    
    log_input "電話番号を入力してください (例: +81.1234567890): "
    read -p "> " phone_number
    phone_number=${phone_number:-"+81.1234567890"}
    
    log_input "住所（1行目）を入力してください: "
    read -p "> " address_line_1
    address_line_1=${address_line_1:-"123 Main Street"}
    
    log_input "市区町村を入力してください: "
    read -p "> " city
    city=${city:-"Tokyo"}
    
    log_input "都道府県を入力してください: "
    read -p "> " state
    state=${state:-"Tokyo"}
    
    log_input "国コードを入力してください (例: JP): "
    read -p "> " country_code
    country_code=${country_code:-"JP"}
    
    log_input "郵便番号を入力してください: "
    read -p "> " zip_code
    zip_code=${zip_code:-"100-0001"}
    
    # 設定の確認
    echo ""
    log_info "設定内容を確認してください:"
    echo "=================================="
    echo "ドメイン名: $domain_name"
    echo "スナップショット日付: $snapshot_date"
    echo "SSH許可IP: $ssh_allowed_cidr"
    echo "検証用EC2: $enable_validation_ec2"
    echo "検証用RDS: $enable_validation_rds"
    echo "ドメイン登録: $register_domain"
    echo ""
    echo "登録者情報:"
    echo "  姓: $first_name"
    echo "  名: $last_name"
    echo "  組織名: $organization_name"
    echo "  メール: $email"
    echo "  電話: $phone_number"
    echo "  住所: $address_line_1"
    echo "  市区町村: $city"
    echo "  都道府県: $state"
    echo "  国コード: $country_code"
    echo "  郵便番号: $zip_code"
    echo "=================================="
    
    log_input "この設定で続行しますか？ (y/N): "
    read -p "> " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "設定をキャンセルしました"
        exit 0
    fi
}

# 設定ファイルの生成
generate_config() {
    local domain_name=$1
    local snapshot_date=$2
    local ssh_allowed_cidr=$3
    local enable_validation_ec2=$4
    local enable_validation_rds=$5
    local first_name=$6
    local last_name=$7
    local organization_name=$8
    local email=$9
    local phone_number=${10}
    local address_line_1=${11}
    local city=${12}
    local state=${13}
    local country_code=${14}
    local zip_code=${15}
    local register_domain=${16:-"true"}
    
    log_info "terraform.tfvarsを生成中..."
    
    # 既存のファイルをバックアップ
    if [ -f "terraform.tfvars" ]; then
        cp terraform.tfvars "terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "既存のterraform.tfvarsをバックアップしました"
    fi
    
    # 新しいterraform.tfvarsを作成
    cat > terraform.tfvars << EOF
aws_region = "ap-northeast-1"
aws_profile = "default"

# ドメイン設定
domain_name = "$domain_name"

# スナップショット設定
snapshot_date = "$snapshot_date"

# 検証環境の設定
enable_validation_ec2 = $enable_validation_ec2    # 検証用EC2（停止状態で作成）
enable_validation_rds = $enable_validation_rds    # 検証用RDS（停止状態で作成）

# SSH接続許可IP（セキュリティ強化）
# 例: "203.0.113.0/24"  # 特定のIPレンジ
# 例: "192.168.1.0/24"   # ローカルネットワーク
# 注意: 本番環境では必ず特定IPに制限してください
ssh_allowed_cidr = "$ssh_allowed_cidr"

# ドメイン登録設定
register_domain = $register_domain  # 新規ドメイン: true, 既存ドメイン: false

# ドメイン登録者情報
registrant_info = {
  first_name        = "$first_name"
  last_name         = "$last_name"
  organization_name = "$organization_name"
  email            = "$email"
  phone_number     = "$phone_number"
  address_line_1   = "$address_line_1"
  city             = "$city"
  state            = "$state"
  country_code     = "$country_code"
  zip_code         = "$zip_code"
}
EOF
    
    log_info "terraform.tfvarsを生成しました"
    
    # deployment_config.jsonの更新
    log_info "deployment_config.jsonを更新中..."
    
    cat > deployment_config.json << EOF
{
    "production": {
        "ec2_instance_id": "",
        "rds_identifier": "wp-shamo-rds",
        "wordpress_url": "http://$domain_name",
        "backup_retention_days": 7
    },
    "validation": {
        "ec2_instance_id": "",
        "rds_identifier": "wp-shamo-rds-validation",
        "wordpress_url": "http://validation-ip",
        "test_timeout_minutes": 30
    },
    "deployment": {
        "auto_approve": false,
        "rollback_on_failure": true,
        "notification_email": ""
    }
}
EOF
    
    log_info "deployment_config.jsonを更新しました"
    
    # ドメイン登録の確認
    echo ""
    if [ "$register_domain" = "true" ]; then
        log_warn "新規ドメインとして検出されました: $domain_name"
        log_input "ドメイン登録を実行しますか？ (y/N): "
        read -p "> " confirm_domain_registration
        if [ "$confirm_domain_registration" != "y" ] && [ "$confirm_domain_registration" != "Y" ]; then
            log_info "ドメイン登録をスキップします"
            # register_domainをfalseに変更
            sed -i 's/^register_domain = true.*$/register_domain = false  # ドメイン登録をスキップ/' terraform.tfvars
            log_info "terraform.tfvarsを更新しました: register_domain = false"
        else
            log_info "ドメイン登録を実行します: register_domain = true"
        fi
    else
        log_info "既存ドメインとして検出されました: $domain_name"
        log_info "ドメイン登録はスキップされます: register_domain = false"
    fi
}

# 既存設定の更新
update_existing_config() {
    log_info "既存設定の更新を開始します..."
    
    # ドメイン名を取得
    if [ -f "terraform.tfvars" ]; then
        local domain_name=$(grep "^domain_name" terraform.tfvars | cut -d'"' -f2)
        log_info "対象ドメイン: $domain_name"
    else
        log_error "terraform.tfvarsファイルが見つかりません"
        exit 1
    fi
    
    # 既存ドメインの検出
    check_existing_domain "$domain_name"
    
    log_info "terraform.tfvarsを更新中..."
    
    # 既存のファイルをバックアップ
    if [ -f "terraform.tfvars" ]; then
        cp terraform.tfvars "terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "既存のterraform.tfvarsをバックアップしました"
    fi
    
    # register_domainの値を更新
    if [ "$register_domain" = "true" ]; then
        # 新規ドメインの場合
        sed -i 's/^register_domain = false.*$/register_domain = true  # 新規ドメインのためtrueに設定/' terraform.tfvars
        log_info "新規ドメインとして設定しました: register_domain = true"
    else
        # 既存ドメインの場合
        sed -i 's/^register_domain = true.*$/register_domain = false  # 既存ドメインのためfalseに設定/' terraform.tfvars
        sed -i 's/^register_domain = false.*$/register_domain = false  # 既存ドメインのためfalseに設定/' terraform.tfvars
        log_info "既存ドメインとして設定しました: register_domain = false"
    fi
    
    log_info "terraform.tfvarsの更新が完了しました"
    
    # ドメイン登録の確認
    echo ""
    if [ "$register_domain" = "true" ]; then
        log_warn "新規ドメインとして検出されました: $domain_name"
        log_input "ドメイン登録を実行しますか？ (y/N): "
        read -p "> " confirm_domain_registration
        if [ "$confirm_domain_registration" != "y" ] && [ "$confirm_domain_registration" != "Y" ]; then
            log_info "ドメイン登録をスキップします"
            # register_domainをfalseに変更
            sed -i 's/^register_domain = true.*$/register_domain = false  # ドメイン登録をスキップ/' terraform.tfvars
            log_info "terraform.tfvarsを更新しました: register_domain = false"
        else
            log_info "ドメイン登録を実行します: register_domain = true"
        fi
    else
        log_info "既存ドメインとして検出されました: $domain_name"
        log_info "ドメイン登録はスキップされます: register_domain = false"
    fi
}

# メイン処理
main() {
    # ヘルプ表示
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi
    
    # 更新モードの確認
    if [ "$1" = "--update-only" ]; then
        update_existing_config
    else
        # 新規設定モード
        interactive_input
        generate_config "$domain_name" "$snapshot_date" "$ssh_allowed_cidr" "$enable_validation_ec2" "$enable_validation_rds" "$first_name" "$last_name" "$organization_name" "$email" "$phone_number" "$address_line_1" "$city" "$state" "$country_code" "$zip_code" "$register_domain"
    fi
    
    log_info "設定完了"
    echo ""
    log_info "次のコマンドでTerraformを実行できます:"
    echo "  terraform plan"
    echo "  terraform apply"
    echo ""
    log_warn "注意: 本番環境では必ずSSH許可IPを特定のIPに制限してください"
}

# スクリプト実行時の処理
main "$@" 