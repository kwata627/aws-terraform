#!/bin/bash

# =============================================================================
# ドメイン登録時のネームサーバー情報取得スクリプト
# =============================================================================
# 
# このスクリプトは指定されたドメインの登録時のネームサーバー情報を取得します。
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
ドメイン登録時のネームサーバー情報取得スクリプト

使用方法:
    $0 [オプション]

オプション:
    -d, --domain DOMAIN    確認するドメイン名
    -t, --terraform        Terraformモード（JSON出力のみ）
    -h, --help            このヘルプを表示

例:
    $0 -d example.com
    $0 -d example.com -t

EOF
}

# デフォルト値
DOMAIN_NAME=""
TERRAFORM_MODE=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -t|--terraform)
            TERRAFORM_MODE=true
            shift
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
    echo -n "確認するドメイン名を入力してください: "
    read DOMAIN_NAME
fi

# ドメイン名の検証
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "無効なドメイン名です: $DOMAIN_NAME"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "{\"error\": \"Invalid domain name\", \"domain_name\": \"$DOMAIN_NAME\", \"nameservers\": [], \"nameserver_count\": 0}"
    fi
    exit 1
fi

log_info "ドメイン名: $DOMAIN_NAME"

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    log_error "AWS CLIがインストールされていません"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "{\"error\": \"AWS CLI not installed\", \"domain_name\": \"$DOMAIN_NAME\", \"nameservers\": [], \"nameserver_count\": 0}"
    fi
    exit 1
fi

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証情報が設定されていません"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "{\"error\": \"AWS credentials not configured\", \"domain_name\": \"$DOMAIN_NAME\", \"nameservers\": [], \"nameserver_count\": 0}"
    fi
    exit 1
fi

# ドメイン登録時のネームサーバー情報を取得
log_info "ドメイン登録時のネームサーバー情報を取得中..."

# 方法1: Route53 Domains APIでドメイン詳細を取得（フォールバック用）
DOMAIN_DETAIL=$(aws route53domains get-domain-detail --domain-name "$DOMAIN_NAME" --region us-east-1 2>/dev/null || echo "")

# 方法2: 実際のDNSクエリでネームサーバー情報を取得（推奨）
# 信頼できるネームサーバーを使用してDNSクエリを実行
TRUSTED_NAMESERVERS=(
    "8.8.8.8"      # Google DNS
    "1.1.1.1"      # Cloudflare DNS
    "208.67.222.222" # OpenDNS
)

NAMESERVERS_FROM_DNS=""
for ns in "${TRUSTED_NAMESERVERS[@]}"; do
    log_info "DNSクエリを実行中: $ns"
    DNS_RESULT=$(dig @$ns "$DOMAIN_NAME" NS +short 2>/dev/null)
    if [[ -n "$DNS_RESULT" ]]; then
        NAMESERVERS_FROM_DNS="$DNS_RESULT"
        log_info "DNSクエリ成功: $ns（順序を保持）"
        break
    fi
done

# 方法3: Route53 APIでホストゾーンのNSレコードを取得（バックアップ）
if [[ -z "$NAMESERVERS_FROM_DNS" ]]; then
    log_info "DNSクエリが失敗したため、Route53 APIを使用します"
    
    # ホストゾーンIDを取得
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" --output text 2>/dev/null | head -1 | sed 's|/hostedzone/||')
    
    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        # NSレコードを取得（順序を保持）
        NS_RECORDS=$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --query "ResourceRecordSets[?Type=='NS'].ResourceRecords[].Value" --output text 2>/dev/null | tr '\t' '\n')
        if [[ -n "$NS_RECORDS" ]]; then
            NAMESERVERS_FROM_DNS="$NS_RECORDS"
            log_info "Route53 APIからNSレコードを取得しました（順序を保持）"
            log_info "注意: Route53 APIの順序は実際のDNSクエリの順序と異なる場合があります"
        fi
    fi
fi

# 最終的なネームサーバー情報の決定
if [[ -n "$NAMESERVERS_FROM_DNS" ]]; then
    # DNSクエリまたはRoute53 APIの結果を使用（順序を保持）
    NAMESERVERS="$NAMESERVERS_FROM_DNS"
    log_info "DNSクエリ/Route53 APIからネームサーバー情報を取得しました（順序を保持）"
elif [[ -n "$DOMAIN_DETAIL" ]]; then
    # Route53 Domains APIの結果を使用（フォールバック）
    NAMESERVERS=$(echo "$DOMAIN_DETAIL" | jq -r '.Nameservers[].Name' 2>/dev/null || echo "")
    log_info "Route53 Domains APIからネームサーバー情報を取得しました（フォールバック）"
else
    log_error "ネームサーバー情報を取得できませんでした"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "{\"error\": \"Nameservers not found\", \"domain_name\": \"$DOMAIN_NAME\", \"nameservers\": [], \"nameserver_count\": 0}"
    fi
    exit 1
fi

if [[ -z "$NAMESERVERS" ]]; then
    log_error "ネームサーバー情報を取得できませんでした"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "{\"error\": \"Nameservers not found\", \"domain_name\": \"$DOMAIN_NAME\", \"nameservers\": [], \"nameserver_count\": 0}"
    fi
    exit 1
fi

# ネームサーバーを配列に変換（順序を保持）
NAMESERVER_ARRAY=()
while IFS= read -r nameserver; do
    if [[ -n "$nameserver" ]]; then
        NAMESERVER_ARRAY+=("$nameserver")
    fi
done <<< "$NAMESERVERS"

# 順序を確認（デバッグ用）
if [[ "$TERRAFORM_MODE" != "true" ]]; then
    log_info "取得したネームサーバーの順序:"
    for i in "${!NAMESERVER_ARRAY[@]}"; do
        log_info "  $((i+1)). ${NAMESERVER_ARRAY[$i]}"
    done
fi

# 結果の表示
if [[ "$TERRAFORM_MODE" == "true" ]]; then
    # Terraformモード: JSON出力のみ（Terraform external data source用）
    NAMESERVERS_JSON=$(printf '%s\n' "${NAMESERVER_ARRAY[@]}" | jq -R . | jq -s . -c)
    jq -n \
        --arg domain "$DOMAIN_NAME" \
        --arg nameservers "$NAMESERVERS_JSON" \
        --arg nameserver_count "${#NAMESERVER_ARRAY[@]}" \
        '{
            domain_name: $domain,
            nameservers: $nameservers,
            nameserver_count: $nameserver_count
        }'
else
    # 通常モード: 詳細出力
    log_success "ドメイン '$DOMAIN_NAME' のネームサーバー情報を取得しました"
    echo
    echo "ネームサーバー情報:"
    for i in "${!NAMESERVER_ARRAY[@]}"; do
        echo "  $((i+1)). ${NAMESERVER_ARRAY[$i]}"
    done
    echo
    echo "ネームサーバー数: ${#NAMESERVER_ARRAY[@]}"
    echo
    echo "JSON形式:"
    jq -n \
        --arg domain "$DOMAIN_NAME" \
        --argjson nameservers "$(printf '%s\n' "${NAMESERVER_ARRAY[@]}" | jq -R . | jq -s .)" \
        '{
            domain_name: $domain,
            nameservers: $nameservers,
            nameserver_count: ($nameservers | length)
        }'
fi
