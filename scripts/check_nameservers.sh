#!/bin/bash

# =============================================================================
# Nameserver Check Script
# =============================================================================
# 
# このスクリプトは、既存ドメインのネームサーバー情報を確認します。
# ACM証明書の検証が失敗する場合のトラブルシューティング用です。
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
Nameserver Check Script

使用方法:
    $0 [オプション] <ドメイン名>

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力
    -a, --aws-only      AWS Route53の情報のみ表示
    -d, --dns-only      DNSクエリの結果のみ表示

例:
    $0 example.com                    # 基本的な確認
    $0 -v example.com                 # 詳細出力
    $0 -a example.com                 # AWS Route53情報のみ
    $0 -d example.com                 # DNSクエリ結果のみ

EOF
}

# デフォルト値
VERBOSE=false
AWS_ONLY=false
DNS_ONLY=false

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
        -a|--aws-only)
            AWS_ONLY=true
            shift
            ;;
        -d|--dns-only)
            DNS_ONLY=true
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

# 環境変数からTerraformモードを確認
if [ "$TERRAFORM_MODE" = "true" ]; then
    # Terraformモードの場合は詳細出力を無効化
    VERBOSE=false
    AWS_ONLY=false
    DNS_ONLY=false
fi

# ドメイン名の確認
if [ -z "$DOMAIN_NAME" ]; then
    error "ドメイン名を指定してください"
    show_help
    exit 1
fi

# ドメイン名の正規化
DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr '[:upper:]' '[:lower:]')

# DNSクエリでネームサーバーを確認
check_dns_nameservers() {
    log "DNSクエリでネームサーバーを確認中..."
    
    # digコマンドでネームサーバーを取得
    if command -v dig &> /dev/null; then
        local ns_records=$(dig +short NS "$DOMAIN_NAME" 2>/dev/null | sort)
        
        if [ -n "$ns_records" ]; then
            success "DNSクエリでネームサーバーを取得しました"
            echo "ネームサーバー（DNSクエリ）:"
            echo "$ns_records" | while read -r ns; do
                echo "  - $ns"
            done
            echo
        else
            warning "DNSクエリでネームサーバーを取得できませんでした"
        fi
    else
        warning "digコマンドが見つかりません"
    fi
    
    # nslookupコマンドでネームサーバーを取得
    if command -v nslookup &> /dev/null; then
        local nslookup_result=$(nslookup -type=ns "$DOMAIN_NAME" 2>/dev/null | grep "nameserver" | awk '{print $NF}' | sort)
        
        if [ -n "$nslookup_result" ]; then
            success "nslookupでネームサーバーを取得しました"
            echo "ネームサーバー（nslookup）:"
            echo "$nslookup_result" | while read -r ns; do
                echo "  - $ns"
            done
            echo
        else
            warning "nslookupでネームサーバーを取得できませんでした"
        fi
    else
        warning "nslookupコマンドが見つかりません"
    fi
}

# AWS Route53でネームサーバーを確認
check_aws_nameservers() {
    log "AWS Route53でネームサーバーを確認中..."
    
    # AWS CLIの確認
    if ! command -v aws &> /dev/null; then
        error "AWS CLIが見つかりません"
        return 1
    fi
    
    # AWS認証情報の確認
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS認証情報が設定されていません"
        return 1
    fi
    
    # Route53ホストゾーンの検索
    local hosted_zones=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN_NAME}.'].{Id:Id,Name:Name}" --output json 2>/dev/null)
    
    if [ "$hosted_zones" != "[]" ]; then
        success "Route53ホストゾーンが見つかりました"
        
        # ホストゾーンIDを取得
        local zone_id=$(echo "$hosted_zones" | jq -r '.[0].Id' 2>/dev/null)
        
        if [ -n "$zone_id" ] && [ "$zone_id" != "null" ]; then
            # ネームサーバーを取得
            local nameservers=$(aws route53 get-hosted-zone --id "$zone_id" --query "DelegationSet.NameServers" --output json 2>/dev/null)
            
            if [ -n "$nameservers" ] && [ "$nameservers" != "null" ]; then
                success "Route53ネームサーバーを取得しました"
                echo "Route53ネームサーバー:"
                echo "$nameservers" | jq -r '.[]' 2>/dev/null | while read -r ns; do
                    echo "  - $ns"
                done
                echo
                
                # ホストゾーンの詳細情報
                if [ "$VERBOSE" = true ]; then
                    local zone_info=$(aws route53 get-hosted-zone --id "$zone_id" --output json 2>/dev/null)
                    echo "ホストゾーン詳細:"
                    echo "  ID: $zone_id"
                    echo "  名前: $(echo "$zone_info" | jq -r '.HostedZone.Name')"
                    echo "  レコード数: $(echo "$zone_info" | jq -r '.HostedZone.ResourceRecordSetCount')"
                    echo "  プライベート: $(echo "$zone_info" | jq -r '.HostedZone.Config.PrivateZone // false')"
                    echo
                fi
            else
                warning "Route53ネームサーバーを取得できませんでした"
            fi
        else
            warning "ホストゾーンIDを取得できませんでした"
        fi
    else
        warning "Route53ホストゾーンが見つかりませんでした"
    fi
}

# ドメイン登録情報を確認
check_domain_registration() {
    log "ドメイン登録情報を確認中..."
    
    # whoisコマンドでドメイン情報を取得
    if command -v whois &> /dev/null; then
        local whois_result=$(whois "$DOMAIN_NAME" 2>/dev/null)
        
        if [ -n "$whois_result" ]; then
            success "whoisでドメイン情報を取得しました"
            
            # ネームサーバー情報を抽出
            local whois_ns=$(echo "$whois_result" | grep -i "name server\|nameserver" | head -10)
            
            if [ -n "$whois_ns" ]; then
                echo "whoisネームサーバー情報:"
                echo "$whois_ns" | while read -r line; do
                    echo "  $line"
                done
                echo
            else
                warning "whoisでネームサーバー情報が見つかりませんでした"
            fi
            
            # 登録者情報を抽出
            if [ "$VERBOSE" = true ]; then
                local registrar=$(echo "$whois_result" | grep -i "registrar" | head -3)
                local creation_date=$(echo "$whois_result" | grep -i "creation date\|created" | head -1)
                local expiry_date=$(echo "$whois_result" | grep -i "expiry date\|expires" | head -1)
                
                if [ -n "$registrar" ]; then
                    echo "登録者情報:"
                    echo "$registrar" | while read -r line; do
                        echo "  $line"
                    done
                fi
                
                if [ -n "$creation_date" ]; then
                    echo "作成日: $creation_date"
                fi
                
                if [ -n "$expiry_date" ]; then
                    echo "有効期限: $expiry_date"
                fi
                echo
            fi
        else
            warning "whoisでドメイン情報を取得できませんでした"
        fi
    else
        warning "whoisコマンドが見つかりません"
    fi
}

# ACM証明書の検証状況を確認
check_acm_certificate() {
    log "ACM証明書の検証状況を確認中..."
    
    # AWS CLIの確認
    if ! command -v aws &> /dev/null; then
        error "AWS CLIが見つかりません"
        return 1
    fi
    
    # ACM証明書を検索
    local certificates=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='${DOMAIN_NAME}' || DomainName=='*.${DOMAIN_NAME}']" --output json 2>/dev/null)
    
    if [ "$certificates" != "[]" ]; then
        success "ACM証明書が見つかりました"
        
        echo "$certificates" | jq -r '.[] | "証明書ARN: \(.CertificateArn)\n状態: \(.Status)\nドメイン: \(.DomainName)\n"' 2>/dev/null
        
        # 証明書の詳細情報を取得
        local cert_arn=$(echo "$certificates" | jq -r '.[0].CertificateArn' 2>/dev/null)
        
        if [ -n "$cert_arn" ] && [ "$cert_arn" != "null" ]; then
            local cert_detail=$(aws acm describe-certificate --certificate-arn "$cert_arn" --output json 2>/dev/null)
            
            if [ -n "$cert_detail" ]; then
                local validation_status=$(echo "$cert_detail" | jq -r '.Certificate.Status' 2>/dev/null)
                local validation_method=$(echo "$cert_detail" | jq -r '.Certificate.DomainValidationOptions[0].ValidationMethod' 2>/dev/null)
                
                echo "検証状況: $validation_status"
                echo "検証方法: $validation_method"
                
                if [ "$validation_method" = "DNS" ]; then
                    local validation_records=$(echo "$cert_detail" | jq -r '.Certificate.DomainValidationOptions[0].ResourceRecord' 2>/dev/null)
                    
                    if [ -n "$validation_records" ] && [ "$validation_records" != "null" ]; then
                        echo "検証レコード:"
                        echo "  名前: $(echo "$validation_records" | jq -r '.Name')"
                        echo "  値: $(echo "$validation_records" | jq -r '.Value')"
                        echo "  タイプ: $(echo "$validation_records" | jq -r '.Type')"
                    fi
                fi
                echo
            fi
        fi
    else
        warning "ACM証明書が見つかりませんでした"
    fi
}

# Terraform用のJSON出力
output_terraform_result() {
    local domain_exists_in_route53=false
    local domain_exists_in_dns=false
    local domain_registered=false
    
    # Route53での存在確認
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        local hosted_zones=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN_NAME}.'].{Id:Id,Name:Name}" --output json 2>/dev/null)
        if [ "$hosted_zones" != "[]" ]; then
            domain_exists_in_route53=true
            # 既存ゾーンの詳細情報を取得
            local zone_id=$(echo "$hosted_zones" | jq -r '.[0].Id' 2>/dev/null | sed 's|/hostedzone/||')
            if [ -n "$zone_id" ] && [ "$zone_id" != "null" ]; then
                local zone_info=$(aws route53 get-hosted-zone --id "$zone_id" --output json 2>/dev/null)
                if [ -n "$zone_info" ]; then
                    echo "既存ホストゾーン情報:" >&2
                    echo "  ID: $zone_id" >&2
                    echo "  名前: $(echo "$zone_info" | jq -r '.HostedZone.Name')" >&2
                    echo "  レコード数: $(echo "$zone_info" | jq -r '.HostedZone.ResourceRecordSetCount')" >&2
                fi
            fi
        fi
    fi
    
    # DNSでの存在確認
    if command -v dig &> /dev/null; then
        local ns_records=$(dig +short NS "$DOMAIN_NAME" 2>/dev/null)
        if [ -n "$ns_records" ]; then
            domain_exists_in_dns=true
        fi
    fi
    
    # ドメイン登録確認（Route53 Domainsで登録済みかチェック）
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        local existing_domains=$(aws route53domains list-domains --region us-east-1 --query "Domains[?DomainName=='$DOMAIN_NAME'].DomainName" --output text 2>/dev/null)
        if [ "$existing_domains" == "$DOMAIN_NAME" ]; then
            domain_registered=true
        fi
    fi
    
    # 既存ゾーンを使用するかどうかの判定
    local should_use_existing="$domain_exists_in_route53"
    
    # ドメイン登録が必要かどうかの判定
    local should_register_domain="false"
    if [ "$domain_registered" = "false" ]; then
        should_register_domain="true"
    fi
    
    # JSON形式で結果を出力
    cat << EOF
{
  "domain_name": "$DOMAIN_NAME",
  "domain_exists_in_route53": "$domain_exists_in_route53",
  "domain_exists_in_dns": "$domain_exists_in_dns",
  "domain_registered": "$domain_registered",
  "should_use_existing": "$should_use_existing",
  "should_register_domain": "$should_register_domain"
}
EOF
}

# メイン処理
main() {
    # Terraformモードの場合はJSON出力のみ
    if [ "$TERRAFORM_MODE" = "true" ]; then
        output_terraform_result
        return 0
    fi
    
    log "=== ネームサーバー確認開始 ==="
    echo "対象ドメイン: $DOMAIN_NAME"
    echo
    
    # DNSクエリの確認
    if [ "$AWS_ONLY" = false ]; then
        check_dns_nameservers
    fi
    
    # AWS Route53の確認
    if [ "$DNS_ONLY" = false ]; then
        check_aws_nameservers
    fi
    
    # ドメイン登録情報の確認
    if [ "$VERBOSE" = true ] && [ "$AWS_ONLY" = false ] && [ "$DNS_ONLY" = false ]; then
        check_domain_registration
    fi
    
    # ACM証明書の確認
    if [ "$VERBOSE" = true ] && [ "$DNS_ONLY" = false ]; then
        check_acm_certificate
    fi
    
    # トラブルシューティングのヒント
    echo "トラブルシューティングのヒント:"
    echo "1. DNSクエリとRoute53のネームサーバーが一致しているか確認してください"
    echo "2. ネームサーバーの変更が反映されるまで最大48時間かかる場合があります"
    echo "3. ACM証明書の検証レコードが正しく作成されているか確認してください"
    echo "4. ドメインのネームサーバー設定が正しいか確認してください"
    echo
    
    log "=== ネームサーバー確認完了 ==="
}

# スクリプト実行
main "$@"
