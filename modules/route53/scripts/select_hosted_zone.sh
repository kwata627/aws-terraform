#!/bin/bash

# =============================================================================
# Route53 Hosted Zone Selection Script
# =============================================================================
# 
# このスクリプトは、複数のRoute53ホストゾーンが存在する場合に
# 適切なホストゾーンを選択します。
# =============================================================================

set -e

# デフォルト値
DOMAIN_NAME=""
TERRAFORM_MODE=false
VERBOSE=false

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: $0 [オプション]

オプション:
    -d, --domain DOMAIN    ドメイン名（必須）
    -t, --terraform        Terraformモード（JSON出力）
    -v, --verbose          詳細出力
    -h, --help            このヘルプを表示

例:
    $0 -d example.com
    $0 -d example.com -t
EOF
}

# 引数の解析
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
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "エラー: 不明なオプション $1"
            show_help
            exit 1
            ;;
    esac
done

# 必須パラメータのチェック
if [[ -z "$DOMAIN_NAME" ]]; then
    echo "エラー: ドメイン名を指定してください"
    show_help
    exit 1
fi

# ログ関数
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# エラーログ関数
error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# 結果出力関数
output_result() {
    local result="$1"
    if [[ "$TERRAFORM_MODE" == "true" ]]; then
        echo "$result"
    else
        echo "結果: $result"
    fi
}

# メイン処理
main() {
    log "ドメイン名: $DOMAIN_NAME"
    
    # ホストゾーンの一覧を取得
    log "Route53ホストゾーンの一覧を取得中..."
    
    local hosted_zones
    if ! hosted_zones=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN_NAME}.']" --output json 2>/dev/null); then
        error_log "Route53ホストゾーンの取得に失敗しました"
        output_result '{"error": "failed_to_get_hosted_zones", "message": "Route53ホストゾーンの取得に失敗しました"}'
        exit 1
    fi
    
    # ホストゾーンの数を確認
    local zone_count
    zone_count=$(echo "$hosted_zones" | jq '. | length')
    log "ホストゾーン数: $zone_count"
    
    if [[ "$zone_count" -eq 0 ]]; then
        log "ホストゾーンが見つかりません"
        output_result '{"hosted_zone_exists": "false", "should_create_new": "true", "selected_zone_id": null}'
        return 0
    fi
    
    if [[ "$zone_count" -eq 1 ]]; then
        # 1つのホストゾーンのみ存在
        local zone_id
        zone_id=$(echo "$hosted_zones" | jq -r '.[0].Id' | sed 's|/hostedzone/||')
        log "単一のホストゾーンが見つかりました: $zone_id"
        output_result "{\"hosted_zone_exists\": \"true\", \"should_create_new\": \"false\", \"selected_zone_id\": \"$zone_id\", \"zone_count\": \"$zone_count\"}"
        return 0
    fi
    
    # 複数のホストゾーンが存在する場合
    log "複数のホストゾーンが存在します（$zone_count個）"
    
    # 各ホストゾーンの詳細を取得
    local best_zone_id=""
    local best_zone_score=0
    
    for i in $(seq 0 $((zone_count - 1))); do
        local zone_id
        zone_id=$(echo "$hosted_zones" | jq -r ".[$i].Id" | sed 's|/hostedzone/||')
        
        log "ホストゾーン $((i+1)) を分析中: $zone_id"
        
        # ホストゾーンの詳細情報を取得
        local zone_details
        if zone_details=$(aws route53 get-hosted-zone --id "$zone_id" --output json 2>/dev/null); then
            local zone_name
            zone_name=$(echo "$zone_details" | jq -r '.HostedZone.Name')
            local comment
            comment=$(echo "$zone_details" | jq -r '.HostedZone.Config.Comment // "N/A"')
            local private_zone
            private_zone=$(echo "$zone_details" | jq -r '.HostedZone.Config.PrivateZone // false')
            
            log "  名前: $zone_name"
            log "  コメント: $comment"
            log "  プライベート: $private_zone"
            
            # スコアリング（最適なホストゾーンを選択）
            local score=0
            
            # プライベートゾーンは除外
            if [[ "$private_zone" == "true" ]]; then
                log "  スコア: 0 (プライベートゾーンのため除外)"
                continue
            fi
            
            # 基本スコア
            score=$((score + 10))
            
            # Terraform管理のホストゾーンを優先
            if [[ "$comment" == *"terraform"* ]] || [[ "$comment" == *"Terraform"* ]]; then
                score=$((score + 20))
                log "  スコア: +20 (Terraform管理)"
            fi
            
            # プロジェクト名が含まれている場合
            if [[ "$comment" == *"wordpress-project"* ]]; then
                score=$((score + 15))
                log "  スコア: +15 (プロジェクト名一致)"
            fi
            
            # 最新のホストゾーンを優先（作成日時で判断）
            local creation_date
            creation_date=$(echo "$zone_details" | jq -r '.HostedZone.CallerReference')
            if [[ "$creation_date" == *"terraform"* ]]; then
                score=$((score + 5))
                log "  スコア: +5 (Terraform作成)"
            fi
            
            log "  最終スコア: $score"
            
            # 最高スコアのホストゾーンを記録
            if [[ $score -gt $best_zone_score ]]; then
                best_zone_score=$score
                best_zone_id="$zone_id"
                log "  新しい最適ホストゾーン: $zone_id (スコア: $score)"
            fi
        else
            error_log "ホストゾーン $zone_id の詳細取得に失敗しました"
        fi
    done
    
    if [[ -n "$best_zone_id" ]]; then
        log "最適なホストゾーンを選択: $best_zone_id (スコア: $best_zone_score)"
        output_result "{\"hosted_zone_exists\": \"true\", \"should_create_new\": \"false\", \"selected_zone_id\": \"$best_zone_id\", \"zone_count\": \"$zone_count\", \"selection_score\": \"$best_zone_score\"}"
    else
        log "適切なホストゾーンが見つかりませんでした"
        output_result '{"hosted_zone_exists": "false", "should_create_new": "true", "selected_zone_id": null, "zone_count": "0"}'
    fi
}

# スクリプト実行
main "$@"
