# CloudFront Module

このモジュールはCloudFrontディストリビューションを作成し、セキュアなCDNを提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 特徴

- セキュアなCDN設定
- リアルタイムログ機能
- セキュリティヘッダー
- 監視・アラーム機能
- 詳細なタグ管理

## ファイル構成

```
modules/cloudfront/
├── main.tf              # メイン設定（プロバイダー設定）
├── variables.tf         # 変数定義
├── outputs.tf          # 出力定義
├── locals.tf           # ローカル値定義
├── data.tf            # データソース
├── distribution.tf     # CloudFrontディストリビューション定義
├── logging.tf         # ログ・監視機能
└── README.md          # このファイル
```

## 使用方法

### 基本的な使用例

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project = "my-project"
  environment = "production"
  origin_domain_name = "my-bucket.s3.amazonaws.com"
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
}
```

### セキュリティ機能を有効化した使用例

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project = "my-project"
  environment = "production"
  origin_domain_name = "my-bucket.s3.amazonaws.com"
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
  
  # セキュリティ機能
  enable_security_headers = true
  minimum_protocol_version = "TLSv1.2_2021"
  
  # ログ・監視機能
  enable_access_logs = true
  access_log_retention_days = 90
  
  enable_real_time_logs = true
  enable_monitoring_alarms = true
}
```

### カスタムキャッシュビヘイビアの例

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project = "my-project"
  environment = "production"
  origin_domain_name = "my-bucket.s3.amazonaws.com"
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
  
  # キャッシュ設定
  allowed_methods = ["GET", "HEAD", "OPTIONS"]
  cached_methods = ["GET", "HEAD"]
  min_ttl = 0
  default_ttl = 3600
  max_ttl = 86400
  enable_compression = true
}
```

## 作成されるリソース

### 必須リソース

1. **CloudFront Distribution**
   - セキュアなCDNディストリビューション
   - HTTPS強制リダイレクト
   - 適切なキャッシュ設定

2. **Origin Access Control**
   - S3オリジンアクセス制御
   - セキュアなオリジンアクセス

### オプションリソース

3. **Response Headers Policy** (オプション)
   - セキュリティヘッダーの設定
   - XSS保護、HSTS等

4. **Real-time Log Configuration** (オプション)
   - リアルタイムログ設定
   - Kinesisストリーム連携

5. **S3 Access Logs Bucket** (オプション)
   - アクセスログ用S3バケット
   - 暗号化とライフサイクル管理

6. **CloudWatch Monitoring** (オプション)
   - 監視ロググループ
   - アラーム設定

## セキュリティ機能

### セキュリティヘッダー

- Content-Type-Options
- Frame-Options
- Referrer-Policy
- XSS-Protection
- Strict-Transport-Security

### プロトコル設定

- TLS 1.2以上を強制
- HTTPSリダイレクト
- セキュアなオリジンアクセス

### 監視・ログ

- リアルタイムログ
- アクセスログ
- CloudWatchアラーム

## 変数

### 必須変数

- `project`: プロジェクト名
- `origin_domain_name`: オリジンドメイン名
- `acm_certificate_arn`: ACM証明書ARN

### オプション変数

- `environment`: 環境名（デフォルト: "production"）
- `enable_distribution`: ディストリビューションの有効化
- `enable_ipv6`: IPv6の有効化
- `allowed_methods`: 許可されるHTTPメソッド
- `cached_methods`: キャッシュされるHTTPメソッド
- `enable_security_headers`: セキュリティヘッダーの有効化
- `enable_access_logs`: アクセスログの有効化
- `enable_real_time_logs`: リアルタイムログの有効化
- `enable_monitoring_alarms`: 監視アラームの有効化
- `tags`: 追加のタグ

## 出力

### ディストリビューション情報

- `distribution_id`: ディストリビューションID
- `distribution_arn`: ディストリビューションARN
- `domain_name`: ドメイン名
- `distribution_status`: ステータス
- `distribution_enabled`: 有効化状態

### セキュリティ機能

- `origin_access_control_id`: オリジンアクセス制御ID
- `security_headers_policy_id`: セキュリティヘッダーポリシーID
- `security_features_enabled`: 有効化されたセキュリティ機能

### ログ・監視機能

- `access_logs_bucket_name`: アクセスログバケット名
- `realtime_log_config_arn`: リアルタイムログ設定ARN
- `monitoring_log_group_name`: 監視ロググループ名
- `monitoring_features_enabled`: 有効化された監視機能

### 設定情報

- `distribution_config`: ディストリビューション設定
- `cache_behavior_config`: キャッシュビヘイビア設定
- `module_summary`: モジュールサマリー

## セキュリティベストプラクティス

1. **HTTPS強制**: 常にHTTPSリダイレクトを有効化
2. **セキュリティヘッダー**: セキュリティヘッダーを有効化
3. **TLS 1.2以上**: 最新のTLSプロトコルを使用
4. **アクセスログ**: アクセスログを有効化して監査
5. **リアルタイム監視**: リアルタイムログとアラームを設定

## 注意事項

- CloudFrontディストリビューションの作成には時間がかかります
- リアルタイムログ機能は追加コストが発生します
- アクセスログはS3バケットのストレージコストが発生します
- セキュリティヘッダーはブラウザの互換性を確認してください

## トラブルシューティング

### よくある問題

1. **ディストリビューションの作成に失敗**
   - ACM証明書ARNの形式を確認
   - オリジンドメイン名の形式を確認

2. **アクセスログが作成されない**
   - S3バケットの権限を確認
   - アクセスログ機能が有効化されているか確認

3. **セキュリティヘッダーが適用されない**
   - ブラウザの開発者ツールでヘッダーを確認
   - キャッシュのクリアを試行

## ライセンス

このモジュールはMITライセンスの下で提供されています。 