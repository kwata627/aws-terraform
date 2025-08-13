#!/bin/bash

# ドメインネームサーバー自動更新スクリプト
# 使用方法: ./update_domain_nameservers.sh <domain_name> <nameserver1> <nameserver2> <nameserver3> <nameserver4>

set -e

DOMAIN_NAME="${1}"
NAMESERVER1="${2}"
NAMESERVER2="${3}"
NAMESERVER3="${4}"
NAMESERVER4="${5}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$NAMESERVER1" ] || [ -z "$NAMESERVER2" ] || [ -z "$NAMESERVER3" ] || [ -z "$NAMESERVER4" ]; then
    echo "使用方法: $0 <domain_name> <nameserver1> <nameserver2> <nameserver3> <nameserver4>"
    exit 1
fi

echo "ドメインのネームサーバーを更新中..."
echo "ドメイン: ${DOMAIN_NAME}"
echo "ネームサーバー: ${NAMESERVER1}, ${NAMESERVER2}, ${NAMESERVER3}, ${NAMESERVER4}"

# 現在のネームサーバーを取得
CURRENT_NS=$(aws route53domains get-domain-detail \
    --domain-name "$DOMAIN_NAME" \
    --query 'Nameservers' \
    --output text 2>/dev/null || echo "")

if [ -n "$CURRENT_NS" ]; then
    echo "現在のネームサーバー: ${CURRENT_NS}"
    
    # ネームサーバーが既に正しい場合はスキップ
    if [[ "$CURRENT_NS" == *"$NAMESERVER1"* ]] && \
       [[ "$CURRENT_NS" == *"$NAMESERVER2"* ]] && \
       [[ "$CURRENT_NS" == *"$NAMESERVER3"* ]] && \
       [[ "$CURRENT_NS" == *"$NAMESERVER4"* ]]; then
        echo "✅ ネームサーバーは既に正しく設定されています"
        echo "{\"updated\": false, \"reason\": \"already_correct\", \"current_ns\": \"${CURRENT_NS}\"}"
        exit 0
    fi
fi

# ネームサーバーを更新
aws route53domains update-domain-nameservers \
    --domain-name "$DOMAIN_NAME" \
    --nameservers \
        Name="$NAMESERVER1" \
        Name="$NAMESERVER2" \
        Name="$NAMESERVER3" \
        Name="$NAMESERVER4" \
    --output json

echo "✅ ドメインのネームサーバー更新が完了しました"
echo "{\"updated\": true, \"domain\": \"${DOMAIN_NAME}\", \"nameservers\": [\"${NAMESERVER1}\", \"${NAMESERVER2}\", \"${NAMESERVER3}\", \"${NAMESERVER4}\"]}"
