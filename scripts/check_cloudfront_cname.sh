#!/bin/bash

# CloudFront CNAMEレコード存在チェックスクリプト
# 使用方法: ./check_cloudfront_cname.sh
# 環境変数から値を読み取る: DOMAIN_NAME, HOSTED_ZONE_ID

set -e

# 環境変数から値を取得
DOMAIN_NAME="${DOMAIN_NAME}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID}"
CNAME_SUBDOMAIN="cdn.${DOMAIN_NAME}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$HOSTED_ZONE_ID" ]; then
    echo "使用方法: DOMAIN_NAME=domain.com HOSTED_ZONE_ID=Z1234567890 $0"
    exit 1
fi

# CNAMEレコードの存在チェック
EXISTING_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${CNAME_SUBDOMAIN}.']" \
    --output json 2>/dev/null || echo "[]")

# 結果をJSON形式で出力
if [ "$EXISTING_RECORD" = "[]" ]; then
    echo "{\"exists\": false, \"record_value\": null, \"needs_cleanup\": false}"
else
    RECORD_VALUE=$(echo "$EXISTING_RECORD" | jq -r '.[0].ResourceRecords[0].Value // empty')
    if [[ "$RECORD_VALUE" == *".cloudfront.net" ]]; then
        echo "{\"exists\": true, \"record_value\": \"$RECORD_VALUE\", \"needs_cleanup\": true}"
    else
        echo "{\"exists\": true, \"record_value\": \"$RECORD_VALUE\", \"needs_cleanup\": false}"
    fi
fi

