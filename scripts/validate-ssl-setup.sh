#!/bin/bash

# SSL設定の自動検証・修正スクリプト
# 循環依存、重複レコード、ネームサーバー不一致を自動検出・修正

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/ssl-validation.log"
TERRAFORM_OUTPUT_FILE="$PROJECT_ROOT/terraform_output.json"

# 色付きログ関数
log() {
    echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m" | tee -a "$LOG_FILE"
}

error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "\033[1;33m[WARNING] $1\033[0m" | tee -a "$LOG_FILE"
}

success() {
    echo -e "\033[1;32m[SUCCESS] $1\033[0m" | tee -a "$LOG_FILE"
}

# 前提条件チェック
check_prerequisites() {
    log "前提条件をチェック中..."
    
    # AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLIがインストールされていません"
        exit 1
    fi
    
    # Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraformがインストールされていません"
        exit 1
    fi
    
    # dig
    if ! command -v dig &> /dev/null; then
        error "digコマンドが利用できません"
        exit 1
    fi
    
    # jq
    if ! command -v jq &> /dev/null; then
        error "jqがインストールされていません"
        exit 1
    fi
    
    success "前提条件チェック完了"
}

# Terraform出力の取得
get_terraform_output() {
    log "Terraform出力を取得中..."
    
    if [ ! -f "$TERRAFORM_OUTPUT_FILE" ]; then
        cd "$PROJECT_ROOT"
        terraform output -json > "$TERRAFORM_OUTPUT_FILE"
    fi
    
    success "Terraform出力取得完了"
}

# 1. 循環依存の検出・修正
check_circular_dependency() {
    log "循環依存をチェック中..."
    
    local has_circular_dependency=false
    
    # Route53モジュールでACM検証レコードが作成されているかチェック
    if terraform state list | grep -q "module.route53.aws_route53_record.cert_validation"; then
        warning "循環依存を検出: Route53モジュールでACM検証レコードが作成されています"
        has_circular_dependency=true
    fi
    
    # ACMモジュールでDNS検証レコードが作成されているかチェック
    if ! terraform state list | grep -q "module.acm.aws_route53_record.certificate_validation"; then
        warning "循環依存を検出: ACMモジュールでDNS検証レコードが作成されていません"
        has_circular_dependency=true
    fi
    
    if [ "$has_circular_dependency" = true ]; then
        log "循環依存を修正中..."
        
        # 古いRoute53検証レコードを削除
        if terraform state list | grep -q "module.route53.aws_route53_record.cert_validation"; then
            log "古いRoute53検証レコードを削除中..."
            terraform state rm module.route53.aws_route53_record.cert_validation || true
        fi
        
        # ACMモジュールでDNS検証レコードを作成
        log "ACMモジュールでDNS検証レコードを作成中..."
        terraform apply -target=module.acm.aws_route53_record.certificate_validation -auto-approve
        
        success "循環依存の修正完了"
        return 1
    else
        success "循環依存は検出されませんでした"
        return 0
    fi
}

# 2. 重複レコードの検出・修正
check_duplicate_records() {
    log "重複レコードをチェック中..."
    
    local has_duplicates=false
    
    # Route53で重複する検証レコードをチェック
    local zone_id
    zone_id=$(jq -r '.route53_zone_id.value // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null)
    
    if [ -n "$zone_id" ]; then
        local validation_records
        validation_records=$(aws route53 list-resource-record-sets \
            --hosted-zone-id "$zone_id" \
            --query 'ResourceRecordSets[?Type==`CNAME` && contains(Name, `_cacb619322fc2cb87a11be788dddbc78`)]' \
            --output json 2>/dev/null)
        
        local record_count
        record_count=$(echo "$validation_records" | jq 'length')
        
        if [ "$record_count" -gt 1 ]; then
            warning "重複レコードを検出: $record_count個の検証レコードが存在します"
            has_duplicates=true
        fi
    fi
    
    if [ "$has_duplicates" = true ]; then
        log "重複レコードを修正中..."
        
        # 古いレコードを削除（ACMモジュール以外のもの）
        log "古い検証レコードを削除中..."
        terraform apply -auto-approve
        
        success "重複レコードの修正完了"
        return 1
    else
        success "重複レコードは検出されませんでした"
        return 0
    fi
}

# 3. ネームサーバー不一致の検出・修正
check_nameserver_mismatch() {
    log "ネームサーバー不一致をチェック中..."
    
    local domain_name
    domain_name=$(jq -r '.infrastructure_summary.value.domain_name // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null)
    
    if [ -z "$domain_name" ]; then
        warning "ドメイン名を取得できませんでした"
        return 0
    fi
    
    # 実際のネームサーバーを取得
    local actual_nameservers
    actual_nameservers=$(dig "$domain_name" NS +short | sort)
    
    # Route53ゾーンのネームサーバーを取得
    local expected_nameservers
    expected_nameservers=$(jq -r '.name_servers.value[] // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null | sort)
    
    if [ "$actual_nameservers" != "$expected_nameservers" ]; then
        warning "ネームサーバー不一致を検出"
        log "実際のネームサーバー: $actual_nameservers"
        log "期待されるネームサーバー: $expected_nameservers"
        
        log "ネームサーバーを更新中..."
        
        # ネームサーバー更新コマンドを構築
        local nameserver_args=""
        while IFS= read -r ns; do
            if [ -n "$ns" ]; then
                nameserver_args="$nameserver_args Name=$ns"
            fi
        done <<< "$expected_nameservers"
        
        # ネームサーバーを更新
        local operation_id
        operation_id=$(aws route53domains update-domain-nameservers \
            --domain-name "$domain_name" \
            --nameservers $nameserver_args \
            --region us-east-1 \
            --query 'OperationId' \
            --output text 2>/dev/null)
        
        if [ -n "$operation_id" ]; then
            log "ネームサーバー更新操作ID: $operation_id"
            log "更新完了まで数分かかる場合があります"
            
            # 更新完了を待機
            local max_attempts=30
            local attempt=0
            
            while [ $attempt -lt $max_attempts ]; do
                local status
                status=$(aws route53domains get-operation-detail \
                    --operation-id "$operation_id" \
                    --region us-east-1 \
                    --query 'Status' \
                    --output text 2>/dev/null)
                
                if [ "$status" = "SUCCESSFUL" ]; then
                    success "ネームサーバー更新完了"
                    break
                elif [ "$status" = "FAILED" ]; then
                    error "ネームサーバー更新が失敗しました"
                    return 1
                else
                    log "ネームサーバー更新中... (ステータス: $status)"
                    sleep 10
                    attempt=$((attempt + 1))
                fi
            done
            
            if [ $attempt -eq $max_attempts ]; then
                warning "ネームサーバー更新の完了確認がタイムアウトしました"
            fi
        else
            error "ネームサーバー更新に失敗しました"
            return 1
        fi
        
        return 1
    else
        success "ネームサーバーは一致しています"
        return 0
    fi
}

# 4. DNS伝播の確認
check_dns_propagation() {
    log "DNS伝播をチェック中..."
    
    local domain_name
    domain_name=$(jq -r '.infrastructure_summary.value.domain_name // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null)
    
    if [ -z "$domain_name" ]; then
        warning "ドメイン名を取得できませんでした"
        return 0
    fi
    
    # 検証レコードの存在確認
    local validation_records
    validation_records=$(jq -r '.acm_validation_records.value // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null)
    
    if [ -n "$validation_records" ]; then
        local record_name
        record_name=$(echo "$validation_records" | jq -r '.[] | .name' | head -1)
        
        if [ -n "$record_name" ]; then
            # DNS伝播をチェック
            local dns_result
            dns_result=$(dig "$record_name" CNAME +short 2>/dev/null || echo "")
            
            if [ -n "$dns_result" ]; then
                success "DNS伝播完了: $record_name"
                return 0
            else
                warning "DNS伝播待機中: $record_name"
                return 1
            fi
        fi
    fi
    
    warning "検証レコード情報を取得できませんでした"
    return 1
}

# 5. 証明書状態の確認
check_certificate_status() {
    log "証明書状態をチェック中..."
    
    local certificate_arn
    certificate_arn=$(jq -r '.acm_certificate_arn.value // empty' "$TERRAFORM_OUTPUT_FILE" 2>/dev/null)
    
    if [ -z "$certificate_arn" ]; then
        warning "証明書ARNを取得できませんでした"
        return 1
    fi
    
    local status
    status=$(aws acm describe-certificate \
        --certificate-arn "$certificate_arn" \
        --region us-east-1 \
        --query 'Certificate.Status' \
        --output text 2>/dev/null)
    
    if [ "$status" = "ISSUED" ]; then
        success "証明書が発行されています: $status"
        return 0
    elif [ "$status" = "PENDING_VALIDATION" ]; then
        warning "証明書が検証待ちです: $status"
        return 1
    else
        error "証明書の状態が異常です: $status"
        return 1
    fi
}

# メイン処理
main() {
    log "=== SSL設定自動検証・修正開始 ==="
    
    # 前提条件チェック
    check_prerequisites
    
    # Terraform出力取得
    get_terraform_output
    
    local needs_apply=false
    
    # 1. 循環依存チェック
    if ! check_circular_dependency; then
        needs_apply=true
    fi
    
    # 2. 重複レコードチェック
    if ! check_duplicate_records; then
        needs_apply=true
    fi
    
    # 3. ネームサーバー不一致チェック
    if ! check_nameserver_mismatch; then
        needs_apply=true
    fi
    
    # 4. DNS伝播チェック
    if ! check_dns_propagation; then
        log "DNS伝播の完了を待機中..."
        log "通常24-48時間かかる場合があります"
    fi
    
    # 5. 証明書状態チェック
    if ! check_certificate_status; then
        log "証明書の発行を待機中..."
    fi
    
    # 必要に応じてTerraform apply実行
    if [ "$needs_apply" = true ]; then
        log "Terraform applyを実行中..."
        terraform apply -auto-approve
        success "Terraform apply完了"
    fi
    
    log "=== SSL設定自動検証・修正完了 ==="
}

# スクリプト実行
main "$@"
