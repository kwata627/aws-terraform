#!/bin/bash

# CloudFront CNAMEレコード自動クリーンアップスクリプト
# 使用方法: ./cleanup_cloudfront_cname.sh
# 環境変数から値を読み取る: DOMAIN_NAME, HOSTED_ZONE_ID, RECORD_VALUE

set -e

# 環境変数から値を取得
DOMAIN_NAME="${DOMAIN_NAME}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID}"
RECORD_VALUE="${RECORD_VALUE}"
CNAME_SUBDOMAIN="cdn.${DOMAIN_NAME}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$HOSTED_ZONE_ID" ] || [ -z "$RECORD_VALUE" ]; then
    echo "使用方法: DOMAIN_NAME=domain.com HOSTED_ZONE_ID=Z1234567890 RECORD_VALUE=old.cloudfront.net $0"
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

