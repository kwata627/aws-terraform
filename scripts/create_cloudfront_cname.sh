#!/bin/bash

# CloudFront CNAMEレコード作成スクリプト
# 使用方法: ./create_cloudfront_cname.sh
# 環境変数から値を読み取る: DOMAIN_NAME, HOSTED_ZONE_ID, CLOUDFRONT_DOMAIN_NAME

set -e

# 環境変数から値を取得
DOMAIN_NAME="${DOMAIN_NAME}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID}"
CLOUDFRONT_DOMAIN_NAME="${CLOUDFRONT_DOMAIN_NAME}"
CNAME_SUBDOMAIN="cdn.${DOMAIN_NAME}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$HOSTED_ZONE_ID" ] || [ -z "$CLOUDFRONT_DOMAIN_NAME" ]; then
    echo "使用方法: DOMAIN_NAME=domain.com HOSTED_ZONE_ID=Z1234567890 CLOUDFRONT_DOMAIN_NAME=new.cloudfront.net $0"
    exit 1
fi

echo "CloudFront CNAMEレコードを作成中..."
echo "ドメイン: ${CNAME_SUBDOMAIN}"
echo "CloudFrontドメイン: ${CLOUDFRONT_DOMAIN_NAME}"

# CNAMEレコードの作成
aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{
        \"Changes\": [
            {
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"${CNAME_SUBDOMAIN}.\",
                    \"Type\": \"CNAME\",
                    \"TTL\": 300,
                    \"ResourceRecords\": [
                        {
                            \"Value\": \"${CLOUDFRONT_DOMAIN_NAME}\"
                        }
                    ]
                }
            }
        ]
    }"

echo "✅ CloudFront CNAMEレコードの作成が完了しました"
echo "{\"created\": true, \"cname\": \"${CNAME_SUBDOMAIN}\", \"target\": \"${CLOUDFRONT_DOMAIN_NAME}\"}"

