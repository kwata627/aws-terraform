# Route53 Module

このモジュールは、AWS Route53ホストゾーンとDNSレコードを作成し、WordPress環境のDNS管理を提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 🚀 新機能・改善点

### ベストプラクティス対応
- **モジュール構造の最適化**: 機能別に整理されたリソース配置
- **条件付きリソースの改善**: `for_each`を使用した効率的なリソース管理
- **バリデーション強化**: より厳密な入力検証とエラーメッセージ
- **セキュリティ強化**: 最小権限の原則に基づくIAM設定
- **パフォーマンス最適化**: 不要なリソースの削除と効率的な設定

### セキュリティ機能
- **DNSSEC対応**: DNSレスポンスの整合性保証
- **DNSクエリログ**: セキュリティ監査のためのログ記録
- **IAMロール最適化**: 最小権限の原則に基づく権限設定
- **VPC統合**: プライベートDNS解決によるセキュリティ向上

## 特徴

- **セキュリティ強化**: DNSSEC、DNSクエリログ対応
- **柔軟なDNSレコード管理**: 複数のレコードタイプとルーティング設定
- **ヘルスチェック機能**: エンドポイントの可用性監視
- **監視・ログ機能**: DNSクエリログとCloudWatch統合
- **プライベートホストゾーン**: VPC内DNS解決対応
- **詳細なタグ管理**: リソース管理のための包括的なタグ付け
- **ベストプラクティス準拠**: Terraformの推奨パターンに従った設計

## 使用方法

### 基本的な使用例

```hcl
module "route53" {
  source = "./modules/route53"
  
  project = "my-wordpress"
  
  domain_name = "example.com"
  wordpress_ip = "192.168.1.100"
  
  certificate_validation_records = {
    "example.com" = {
      name   = "_acm-validation.example.com"
      record = "validation-record"
      type   = "CNAME"
    }
  }
}
```

### 高度な設定例（セキュリティ強化版）

```hcl
module "route53" {
  source = "./modules/route53"
  
  project     = "my-wordpress"
  environment = "production"
  
  domain_name = "example.com"
  wordpress_ip = "192.168.1.100"
  cloudfront_domain_name = "d1234567890.cloudfront.net"
  
  # ドメイン登録設定
  register_domain = true
  registrant_info = {
    first_name        = "John"
    last_name         = "Doe"
    organization_name = "My Company"
    email            = "admin@example.com"
    phone_number     = "+81.1234567890"
    address_line_1   = "123 Main Street"
    city             = "Tokyo"
    state            = "Tokyo"
    country_code     = "JP"
    zip_code         = "100-0001"
  }
  
  # 追加のDNSレコード
  dns_records = [
    {
      name    = "www.example.com"
      type    = "A"
      ttl     = 300
      records = ["192.168.1.100"]
    },
    {
      name    = "api.example.com"
      type    = "CNAME"
      ttl     = 300
      records = ["api.example.com.s3-website-ap-northeast-1.amazonaws.com"]
    }
  ]
  
  # ヘルスチェック設定
  enable_health_checks = true
  health_checks = [
    {
      name               = "wordpress-health-check"
      fqdn              = "example.com"
      port               = 80
      type               = "HTTP"
      resource_path      = "/"
      failure_threshold  = 3
      request_interval   = 30
      regions            = ["us-east-1", "ap-northeast-1"]
    }
  ]
  
  # DNSクエリログ設定（セキュリティ監査用）
  enable_query_logging = true
  query_log_group_name = "/aws/route53/example.com"
  query_log_retention_days = 30
  
  # DNSSEC設定（セキュリティ強化）
  enable_dnssec = true
  
  # プライベートホストゾーン設定
  is_private_zone = false
  private_zone_vpc_ids = []
  
  # タグ設定
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "true"
    Security    = "high"
  }
}
```

## 入力変数

### 基本設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| project | プロジェクト名 | `string` | - | はい | 小文字、数字、ハイフンのみ |
| environment | 環境名 | `string` | `"production"` | いいえ | production, staging, development, test |
| domain_name | 管理するドメイン名 | `string` | - | はい | 有効なドメイン名形式 |
| wordpress_ip | WordPress EC2インスタンスのIPアドレス | `string` | `""` | いいえ | IPv4アドレス形式 |
| cloudfront_domain_name | CloudFrontディストリビューションのドメイン名 | `string` | `""` | いいえ | CloudFrontドメイン形式 |
| certificate_validation_records | ACM証明書検証用のDNSレコード情報 | `map(object)` | `{}` | いいえ | 有効なDNSレコード形式 |

### ドメイン登録設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| register_domain | ドメイン登録を実行するかどうか | `bool` | `false` | いいえ | - |
| registrant_info | ドメイン登録者の情報 | `object` | デフォルト値 | いいえ | 必須フィールドの検証 |

### DNSレコード設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| dns_records | 追加のDNSレコード設定 | `list(object)` | `[]` | いいえ | 有効なDNSレコード形式 |

### ヘルスチェック設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_health_checks | ヘルスチェックの有効化 | `bool` | `false` | いいえ | - |
| health_checks | ヘルスチェック設定 | `list(object)` | `[]` | いいえ | 有効なヘルスチェック形式 |

### DNSクエリログ設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_query_logging | DNSクエリログの有効化 | `bool` | `false` | いいえ | - |
| query_log_group_name | CloudWatch Log Group名 | `string` | `""` | いいえ | 英数字、スラッシュ、アンダースコア、ハイフンのみ |
| query_log_retention_days | DNSクエリログの保持期間（日数） | `number` | `30` | いいえ | 1-2555日 |

### DNSSEC設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_dnssec | DNSSECの有効化 | `bool` | `false` | いいえ | - |
| dnssec_signing_algorithm | DNSSEC署名アルゴリズム | `string` | `"RSASHA256"` | いいえ | 有効なアルゴリズム |

### プライベートホストゾーン設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| is_private_zone | プライベートホストゾーンの有効化 | `bool` | `false` | いいえ | - |
| private_zone_vpc_ids | プライベートホストゾーンに関連付けるVPC ID一覧 | `list(string)` | `[]` | いいえ | 有効なVPC ID形式 |

### タグ設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| tags | 追加のタグ | `map(string)` | `{}` | いいえ | キー1-128文字、値256文字以内 |

## 出力

### ホストゾーン関連

| 名前 | 説明 |
|------|------|
| zone_id | 作成したRoute53ホストゾーンのID |
| zone_name | Route53ホストゾーンの名前 |
| zone_arn | Route53ホストゾーンのARN |
| name_servers | Route53ホストゾーンのネームサーバー |
| zone_private | プライベートホストゾーンの有効化状態 |
| zone_name_servers_count | ネームサーバーの数 |

### ドメイン登録関連

| 名前 | 説明 |
|------|------|
| domain_registration_status | ドメイン登録の状態 |
| domain_expiration_date | ドメインの有効期限 |
| domain_auto_renew | ドメインの自動更新状態 |
| registered_domain_name | 登録されたドメイン名 |

### DNSレコード関連

| 名前 | 説明 |
|------|------|
| dns_records_created | 作成されたDNSレコードの数 |
| wordpress_record_name | WordPress用Aレコードの名前 |
| wordpress_record_created | WordPress用Aレコードが作成されたかどうか |
| cloudfront_record_name | CloudFront用CNAMEレコードの名前 |
| cloudfront_record_created | CloudFront用CNAMEレコードが作成されたかどうか |
| cert_validation_records_created | 作成された証明書検証レコードの数 |
| additional_records_created | 作成された追加DNSレコードの数 |

### ヘルスチェック関連

| 名前 | 説明 |
|------|------|
| health_checks_created | 作成されたヘルスチェックの数 |
| health_check_ids | 作成されたヘルスチェックのID一覧 |
| health_check_names | 作成されたヘルスチェックの名前一覧 |
| health_checks_enabled | ヘルスチェックが有効化されているかどうか |

### DNSクエリログ関連

| 名前 | 説明 |
|------|------|
| query_logging_enabled | DNSクエリログの有効化状態 |
| query_log_group_arn | DNSクエリログ用CloudWatch Log GroupのARN |
| query_log_group_name | DNSクエリログ用CloudWatch Log Groupの名前 |
| query_logging_role_arn | DNSクエリログ用IAMロールのARN |
| query_log_retention_days | DNSクエリログの保持期間（日数） |

### DNSSEC関連

| 名前 | 説明 |
|------|------|
| dnssec_enabled | DNSSECの有効化状態 |
| dnssec_key_signing_key | DNSSEC鍵署名鍵の情報 |
| dnssec_key_signing_key_arn | DNSSEC鍵署名鍵のARN |
| dnssec_signing_algorithm | DNSSEC署名アルゴリズム |

### プライベートホストゾーン関連

| 名前 | 説明 |
|------|------|
| private_zone_enabled | プライベートホストゾーンの有効化状態 |
| private_zone_vpc_associations | プライベートホストゾーンに関連付けられたVPC一覧 |
| private_zone_vpc_count | プライベートホストゾーンに関連付けられたVPCの数 |

### サマリー出力

| 名前 | 説明 |
|------|------|
| module_summary | Route53モジュールの設定サマリー |
| security_features | 有効化されているセキュリティ機能 |

## セキュリティ機能

### DNSSEC

- **DNS署名**: DNSレスポンスの整合性保証
- **鍵管理**: KMS統合による鍵管理
- **アルゴリズム選択**: 複数の署名アルゴリズム対応
- **自動鍵ローテーション**: セキュリティ強化

### DNSクエリログ

- **クエリ記録**: すべてのDNSクエリの記録
- **CloudWatch統合**: ログの一元管理
- **保持期間設定**: カスタマイズ可能な保持期間
- **セキュリティ監査**: 不正アクセスの検知

### アクセス制御

- **IAMロール**: 最小権限の原則
- **VPC統合**: プライベートDNS解決
- **レコード保護**: 誤変更防止
- **条件付きアクセス**: アカウント制限

## ベストプラクティス

### DNS管理

1. **TTL設定**: 適切なTTL値の設定
2. **レコード管理**: 一貫した命名規則
3. **冗長性**: 複数のDNSレコード配置
4. **監視**: ヘルスチェックの活用
5. **セキュリティ**: DNSSECの有効化

### セキュリティ

1. **DNSSEC**: 本番環境でのDNSSEC有効化
2. **クエリログ**: セキュリティ監査のためのログ記録
3. **アクセス制御**: 最小権限のIAM設定
4. **暗号化**: 転送中の暗号化
5. **監視**: 異常検知の実装

### 可用性

1. **ヘルスチェック**: エンドポイントの可用性監視
2. **フェイルオーバー**: 冗長性の確保
3. **地理的分散**: 複数リージョンでの配置
4. **自動復旧**: 障害時の自動復旧
5. **負荷分散**: 適切なルーティング設定

### 監視

1. **DNSクエリログ**: トラフィック分析
2. **ヘルスチェック**: エンドポイント監視
3. **CloudWatch統合**: メトリクス収集
4. **アラーム設定**: 異常検知
5. **ダッシュボード**: 可視化

## 料金への影響

### 追加料金が発生する機能

- **DNSクエリログ**: 約$0.50/100万クエリ
- **ヘルスチェック**: 約$0.50/月/チェック
- **DNSSEC**: 約$3.00/月/ゾーン
- **ドメイン登録**: 年間料金（ドメインにより異なる）

### 料金最適化のヒント

1. **TTL最適化**: 適切なTTL値でクエリ削減
2. **ヘルスチェック**: 必要最小限のチェック
3. **ログ保持期間**: 必要最小限の保持期間
4. **プライベートゾーン**: 内部DNS解決の活用
5. **クエリログ**: 本番環境でのみ有効化

## トラブルシューティング

### よくある問題

1. **DNS解決エラー**: ネームサーバー設定の確認
2. **証明書検証失敗**: DNSレコードの設定確認
3. **ヘルスチェック失敗**: エンドポイントの可用性確認
4. **DNSSECエラー**: 鍵設定の確認
5. **クエリログエラー**: IAM権限の確認

### 解決方法

1. ネームサーバーの設定確認
2. DNSレコードのTTLと設定確認
3. エンドポイントのネットワーク接続確認
4. IAMロールとKMS権限の確認
5. CloudWatch Logsの設定確認

## 注意事項

- **ドメイン登録**: 年間更新が必要
- **DNSSEC**: 鍵ローテーションの計画
- **クエリログ**: 大量のログデータ生成
- **コスト**: 使用量に応じた料金発生
- **セキュリティ**: 定期的な監査の実施

## 更新履歴

### v2.0.0 (最新)
- ベストプラクティスに基づくリファクタリング
- セキュリティ機能の強化
- バリデーションの改善
- パフォーマンスの最適化
- より詳細な出力の追加 