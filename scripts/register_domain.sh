#!/bin/bash

# =============================================================================
# 対話形式ドメイン登録スクリプト
# =============================================================================

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
対話形式ドメイン登録スクリプト

使用方法:
    $0 [オプション]

オプション:
    -d, --domain DOMAIN    登録するドメイン名
    -f, --file FILE        terraform.tfvarsファイルのパス
    -h, --help            このヘルプを表示

例:
    $0 -d example.com
    $0 -d example.com -f terraform.tfvars

EOF
}

# デフォルト値
DOMAIN_NAME=""
TFVARS_FILE="terraform.tfvars"

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -f|--file)
            TFVARS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# ドメイン名の入力
if [[ -z "$DOMAIN_NAME" ]]; then
    echo -n "登録するドメイン名を入力してください: "
    read DOMAIN_NAME
fi

# ドメイン名の検証
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "無効なドメイン名です: $DOMAIN_NAME"
    exit 1
fi

log_info "ドメイン名: $DOMAIN_NAME"

# ドメインの利用可能性チェック
log_info "ドメインの利用可能性をチェックしています..."
AVAILABILITY=$(aws route53domains check-domain-availability --domain-name "$DOMAIN_NAME" --region us-east-1 --query 'Availability' --output text)

if [[ "$AVAILABILITY" != "AVAILABLE" ]]; then
    log_error "ドメイン '$DOMAIN_NAME' は利用できません。ステータス: $AVAILABILITY"
    exit 1
fi

log_success "ドメイン '$DOMAIN_NAME' は利用可能です"

# 登録者情報の入力
log_info "登録者情報を入力してください:"

echo -n "姓: "
read LAST_NAME

echo -n "名: "
read FIRST_NAME

echo -n "組織名 (任意、空欄可): "
read ORGANIZATION_NAME

echo -n "メールアドレス: "
read EMAIL

echo -n "電話番号 (例: +81.80-4178-3008): "
read PHONE_NUMBER

echo -n "住所1 (必須): "
read ADDRESS_LINE_1
if [[ -z "$ADDRESS_LINE_1" ]]; then
    echo -n "住所1を入力してください (必須): "
    read ADDRESS_LINE_1
fi

echo -n "市区町村 (必須): "
read CITY
if [[ -z "$CITY" ]]; then
    echo -n "市区町村を入力してください (必須): "
    read CITY
fi

echo -n "都道府県: "
read STATE

echo -n "国コード (例: JP): "
read COUNTRY_CODE

echo -n "郵便番号: "
read ZIP_CODE

# 入力内容の確認
echo
log_info "入力内容の確認:"
echo "ドメイン名: $DOMAIN_NAME"
echo "姓: $LAST_NAME"
echo "名: $FIRST_NAME"
echo "組織名: $ORGANIZATION_NAME"
echo "メールアドレス: $EMAIL"
echo "電話番号: $PHONE_NUMBER"
echo "住所: $ADDRESS_LINE_1"
echo "市区町村: $CITY"
echo "都道府県: $STATE"
echo "国コード: $COUNTRY_CODE"
echo "郵便番号: $ZIP_CODE"

echo
echo -n "この内容で登録しますか？ (y/N): "
read CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_warning "登録をキャンセルしました"
    exit 0
fi

# terraform.tfvarsファイルの更新
log_info "terraform.tfvarsファイルを更新しています..."

# バックアップ作成
cp "$TFVARS_FILE" "${TFVARS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# ドメイン名の更新
sed -i "s/^domain_name = \".*\"/domain_name = \"$DOMAIN_NAME\"/" "$TFVARS_FILE"

# 登録者情報の更新
sed -i "s/^  first_name        = \".*\"/  first_name        = \"$FIRST_NAME\"/" "$TFVARS_FILE"
sed -i "s/^  last_name         = \".*\"/  last_name         = \"$LAST_NAME\"/" "$TFVARS_FILE"
sed -i "s/^  organization_name = \".*\"/  organization_name = \"$ORGANIZATION_NAME\"/" "$TFVARS_FILE"
sed -i "s/^  email            = \".*\"/  email            = \"$EMAIL\"/" "$TFVARS_FILE"
sed -i "s/^  phone_number     = \".*\"/  phone_number     = \"$PHONE_NUMBER\"/" "$TFVARS_FILE"
sed -i "s/^  address_line_1   = \".*\"/  address_line_1   = \"$ADDRESS_LINE_1\"/" "$TFVARS_FILE"
sed -i "s/^  city             = \".*\"/  city             = \"$CITY\"/" "$TFVARS_FILE"
sed -i "s/^  state            = \".*\"/  state            = \"$STATE\"/" "$TFVARS_FILE"
sed -i "s/^  country_code     = \".*\"/  country_code     = \"$COUNTRY_CODE\"/" "$TFVARS_FILE"
sed -i "s/^  zip_code         = \".*\"/  zip_code         = \"$ZIP_CODE\"/" "$TFVARS_FILE"

# ドメイン登録を有効化
sed -i "s/^register_domain = false/register_domain = true/" "$TFVARS_FILE"

log_success "terraform.tfvarsファイルを更新しました"

# Terraformの実行確認
echo
log_info "Terraformでドメイン登録を実行しますか？"
echo -n "実行しますか？ (y/N): "
read RUN_TERRAFORM

if [[ ! "$RUN_TERRAFORM" =~ ^[Yy]$ ]]; then
    log_warning "Terraformの実行をスキップしました"
    log_info "手動で 'terraform apply' を実行してください"
    exit 0
fi

# Terraformの実行
log_info "Terraformを実行しています..."
terraform plan

echo
echo -n "このプランで適用しますか？ (y/N): "
read APPLY_CONFIRM

if [[ ! "$APPLY_CONFIRM" =~ ^[Yy]$ ]]; then
    log_warning "Terraformの適用をキャンセルしました"
    exit 0
fi

terraform apply -auto-approve

log_success "ドメイン登録が完了しました！"
log_info "ドメイン: $DOMAIN_NAME"
log_info "ネームサーバーの設定が完了するまで数分かかる場合があります"
