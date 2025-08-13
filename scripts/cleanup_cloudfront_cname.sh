#!/bin/bash

# CloudFront CNAMEレコード自動クリーンアップスクリプト
# 使用方法: ./cleanup_cloudfront_cname.sh <domain_name> <hosted_zone_id> <record_value>

set -e

DOMAIN_NAME="${1}"
HOSTED_ZONE_ID="${2}"
RECORD_VALUE="${3}"
CNAME_SUBDOMAIN="cdn.${DOMAIN_NAME}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$HOSTED_ZONE_ID" ] || [ -z "$RECORD_VALUE" ]; then
    echo "使用方法: $0 <domain_name> <hosted_zone_id> <record_value>"
    exit 1
fi

echo "CloudFront CNAMEレコードを削除中..."
echo "ドメイン: ${CNAME_SUBDOMAIN}"
echo "レコード値: ${RECORD_VALUE}"

# CNAMEレコードの削除
aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{
        \"Changes\": [
            {
                \"Action\": \"DELETE\",
                \"ResourceRecordSet\": {
                    \"Name\": \"${CNAME_SUBDOMAIN}.\",
                    \"Type\": \"CNAME\",
                    \"TTL\": 300,
                    \"ResourceRecords\": [
                        {
                            \"Value\": \"${RECORD_VALUE}\"
                        }
                    ]
                }
            }
        ]
    }"

echo "✅ CloudFront CNAMEレコードの削除が完了しました"
echo "{\"cleaned_up\": true, \"deleted_record\": \"${RECORD_VALUE}\"}"
