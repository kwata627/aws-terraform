#!/bin/bash

# =============================================================================
# Route53 ドメイン登録・確認スクリプト
# =============================================================================
# 
# このスクリプトはTerraformモジュール内で実行され、
# ドメインの登録状況を確認し、必要に応じて登録を行います。
# =============================================================================

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数（Terraform実行時は無効化）
log_info() {
    if [[ "$TERRAFORM_MODE" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    if [[ "$TERRAFORM_MODE" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

log_warning() {
    if [[ "$TERRAFORM_MODE" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

log_error() {
    if [[ "$TERRAFORM_MODE" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

# ヘルプ表示
show_help() {
    cat << EOF
Route53 ドメイン登録・確認スクリプト

使用方法:
    $0 [オプション]

オプション:
    -d, --domain DOMAIN    確認・登録するドメイン名
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
    echo -n "確認・登録するドメイン名を入力してください: "
    read DOMAIN_NAME
fi

# ドメイン名の検証
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "無効なドメイン名です: $DOMAIN_NAME"
    echo "{\"register_domain\": \"false\", \"domain_unavailable\": \"true\", \"domain_name\": \"$DOMAIN_NAME\"}"
    exit 0
fi

log_info "ドメイン名: $DOMAIN_NAME"

# 既存ドメインの確認
log_info "既存ドメインの確認中..."
EXISTING_DOMAINS=$(aws route53domains list-domains --region us-east-1 --query "Domains[?DomainName=='$DOMAIN_NAME'].DomainName" --output text)

if [[ "$EXISTING_DOMAINS" == "$DOMAIN_NAME" ]]; then
    log_success "ドメイン '$DOMAIN_NAME' は既に登録済みです"
    echo "{\"register_domain\": \"false\", \"domain_name\": \"$DOMAIN_NAME\"}"
    exit 0
fi

log_info "ドメイン '$DOMAIN_NAME' は未登録です"

# ドメインの利用可能性チェック
log_info "ドメインの利用可能性をチェックしています..."
AVAILABILITY=$(aws route53domains check-domain-availability --domain-name "$DOMAIN_NAME" --region us-east-1 --query 'Availability' --output text)

if [[ "$AVAILABILITY" != "AVAILABLE" ]]; then
    log_error "ドメイン '$DOMAIN_NAME' は利用できません。ステータス: $AVAILABILITY"
    echo "{\"register_domain\": \"false\", \"domain_unavailable\": \"true\", \"domain_name\": \"$DOMAIN_NAME\"}"
    exit 0
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

echo -n "電話番号 (例: +81.8041783008): "
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
    echo "{\"register_domain\": \"false\", \"domain_name\": \"$DOMAIN_NAME\"}"
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

# 登録結果を出力（JSON形式）
echo "{\"register_domain\": \"true\", \"domain_name\": \"$DOMAIN_NAME\"}"
