#!/bin/bash

# ネームサーバー更新必要性チェックスクリプト
# 使用方法: ./check_nameserver_update.sh <domain_name> <nameserver1> <nameserver2> <nameserver3> <nameserver4>

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

# ドメインの詳細情報を取得
DOMAIN_DETAIL=$(aws route53domains get-domain-detail \
    --domain-name "$DOMAIN_NAME" \
    --output json 2>/dev/null || echo "{}")

# ドメインが存在しない場合
if [ "$DOMAIN_DETAIL" = "{}" ]; then
    echo "{\"needs_update\": false, \"reason\": \"domain_not_found\", \"domain\": \"${DOMAIN_NAME}\"}"
    exit 0
fi

# 現在のネームサーバーを取得
CURRENT_NS=$(echo "$DOMAIN_DETAIL" | jq -r '.Nameservers[]? // empty' | tr '\n' ' ' | sed 's/ $//')

if [ -z "$CURRENT_NS" ]; then
    echo "{\"needs_update\": true, \"reason\": \"no_nameservers\", \"domain\": \"${DOMAIN_NAME}\", \"current_ns\": null, \"target_ns\": [\"${NAMESERVER1}\", \"${NAMESERVER2}\", \"${NAMESERVER3}\", \"${NAMESERVER4}\"]}"
    exit 0
fi

# ネームサーバーが正しいかチェック
NS_ARRAY=("$NAMESERVER1" "$NAMESERVER2" "$NAMESERVER3" "$NAMESERVER4")
ALL_CORRECT=true

for ns in "${NS_ARRAY[@]}"; do
    if [[ ! "$CURRENT_NS" == *"$ns"* ]]; then
        ALL_CORRECT=false
        break
    fi
done

if [ "$ALL_CORRECT" = true ]; then
    echo "{\"needs_update\": false, \"reason\": \"already_correct\", \"domain\": \"${DOMAIN_NAME}\", \"current_ns\": \"${CURRENT_NS}\"}"
else
    echo "{\"needs_update\": true, \"reason\": \"mismatch\", \"domain\": \"${DOMAIN_NAME}\", \"current_ns\": \"${CURRENT_NS}\", \"target_ns\": [\"${NAMESERVER1}\", \"${NAMESERVER2}\", \"${NAMESERVER3}\", \"${NAMESERVER4}\"]}"
fi
