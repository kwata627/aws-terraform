# S3 Module

このモジュールは、AWS S3バケットを作成し、静的ファイルとログの保存を提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 🚀 新機能・改善点

### ベストプラクティス対応
- **モジュール構造の最適化**: 機能別に整理されたリソース配置
- **セキュリティ強化**: 包括的なアクセス制御と暗号化
- **ライフサイクル管理**: 自動的なオブジェクト管理
- **監視・ログ機能**: アクセスログとインベントリ
- **コスト最適化**: インテリジェントティアリング

### セキュリティ機能
- **暗号化**: サーバーサイド暗号化（AES256/KMS）
- **アクセス制御**: パブリックアクセスブロック
- **バージョニング**: データ保護と復旧
- **MFA削除**: 誤削除防止
- **バケットキー**: パフォーマンス向上

## 特徴

- **セキュリティ強化**: 暗号化、アクセス制御、バージョニング
- **ライフサイクル管理**: 自動的なオブジェクト管理
- **監視・ログ機能**: アクセスログとインベントリ
- **CloudFront統合**: CDNとの連携
- **コスト最適化**: インテリジェントティアリング
- **詳細なタグ管理**: リソース管理のための包括的なタグ付け

## 使用方法

### 基本的な使用例

```hcl
module "s3" {
  source = "./modules/s3"
  
  project = "my-wordpress"
  bucket_name = "static-files"
  
  # セキュリティ設定
  enable_versioning = true
  encryption_algorithm = "AES256"
  
  # CloudFront統合
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}
```

### 高度な設定例（セキュリティ強化版）

```hcl
module "s3" {
  source = "./modules/s3"
  
  project = "my-wordpress"
  environment = "production"
  bucket_name = "static-files"
  bucket_purpose = "static-files"
  
  # セキュリティ設定
  enable_versioning = true
  enable_mfa_delete = true
  encryption_algorithm = "aws:kms"
  kms_key_id = "arn:aws:kms:ap-northeast-1:123456789012:key/example"
  enable_bucket_key = true
  
  # パブリックアクセス制御
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
  object_ownership = "BucketOwnerEnforced"
  bucket_acl = "private"
  
  # ライフサイクル管理
  enable_lifecycle_management = true
  noncurrent_version_transition_days = 30
  noncurrent_version_storage_class = "STANDARD_IA"
  noncurrent_version_expiration_days = 90
  abort_incomplete_multipart_days = 7
  enable_object_expiration = false
  
  # アクセスログ
  enable_access_logging = true
  
  # インベントリ
  enable_inventory = true
  
  # インテリジェントティアリング
  enable_intelligent_tiering = true
  archive_access_days = 90
  deep_archive_access_days = 180
  
  # CloudFront統合
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  
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
| bucket_name | S3バケット名 | `string` | - | はい | 小文字、数字、ハイフンのみ |
| bucket_purpose | バケットの用途 | `string` | `"static-files"` | いいえ | static-files, logs, backup, data, media |
| cloudfront_distribution_arn | CloudFrontディストリビューションのARN | `string` | `""` | いいえ | 有効なCloudFront ARN |

### バージョニング・暗号化設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_versioning | バケットバージョニングの有効化 | `bool` | `true` | いいえ | - |
| enable_mfa_delete | MFA削除の有効化 | `bool` | `false` | いいえ | - |
| encryption_algorithm | サーバーサイド暗号化アルゴリズム | `string` | `"AES256"` | いいえ | AES256, aws:kms |
| kms_key_id | KMSキーID | `string` | `""` | いいえ | 有効なKMS ARN |
| enable_bucket_key | バケットキーの有効化 | `bool` | `true` | いいえ | - |

### パブリックアクセス設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| block_public_acls | パブリックACLのブロック | `bool` | `true` | いいえ | - |
| block_public_policy | パブリックポリシーのブロック | `bool` | `true` | いいえ | - |
| ignore_public_acls | パブリックACLの無視 | `bool` | `true` | いいえ | - |
| restrict_public_buckets | パブリックバケットの制限 | `bool` | `true` | いいえ | - |
| object_ownership | オブジェクト所有権設定 | `string` | `"BucketOwnerEnforced"` | いいえ | BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced |
| bucket_acl | バケットACL | `string` | `"private"` | いいえ | private, public-read, public-read-write, authenticated-read |

### ライフサイクル管理設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_lifecycle_management | ライフサイクル管理の有効化 | `bool` | `true` | いいえ | - |
| noncurrent_version_transition_days | 非現行バージョンの移行日数 | `number` | `30` | いいえ | 0以上 |
| noncurrent_version_storage_class | 非現行バージョンのストレージクラス | `string` | `"STANDARD_IA"` | いいえ | 有効なストレージクラス |
| noncurrent_version_expiration_days | 非現行バージョンの削除日数 | `number` | `90` | いいえ | 0以上 |
| abort_incomplete_multipart_days | 不完全なマルチパートアップロードの削除日数 | `number` | `7` | いいえ | 0以上 |
| enable_object_expiration | オブジェクトの自動削除の有効化 | `bool` | `false` | いいえ | - |
| object_expiration_days | オブジェクトの削除日数 | `number` | `365` | いいえ | 0以上 |

### 監視・ログ設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_access_logging | アクセスログの有効化 | `bool` | `false` | いいえ | - |
| enable_inventory | インベントリの有効化 | `bool` | `false` | いいえ | - |

### インテリジェントティアリング設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| enable_intelligent_tiering | インテリジェントティアリングの有効化 | `bool` | `false` | いいえ | - |
| archive_access_days | アーカイブアクセスまでの日数 | `number` | `90` | いいえ | 0以上 |
| deep_archive_access_days | ディープアーカイブアクセスまでの日数 | `number` | `180` | いいえ | 0以上 |

### タグ設定

| 名前 | 説明 | 型 | デフォルト | 必須 | バリデーション |
|------|------|------|------|------|------|
| tags | 追加のタグ | `map(string)` | `{}` | いいえ | キー1-128文字、値256文字以内 |

## 出力

### バケット情報

| 名前 | 説明 |
|------|------|
| bucket_id | 作成したS3バケットのID |
| bucket_arn | 作成したS3バケットのARN |
| bucket_name | 作成したS3バケットの名前 |
| bucket_domain_name | S3バケットのドメイン名（CloudFrontオリジン用） |
| bucket_region | S3バケットのリージョン |

### バージョニング情報

| 名前 | 説明 |
|------|------|
| versioning_enabled | バージョニングの有効化状態 |
| mfa_delete_enabled | MFA削除の有効化状態 |

### 暗号化情報

| 名前 | 説明 |
|------|------|
| encryption_algorithm | 使用されている暗号化アルゴリズム |
| bucket_key_enabled | バケットキーの有効化状態 |
| kms_key_used | 使用されているKMSキーID |

### パブリックアクセス情報

| 名前 | 説明 |
|------|------|
| public_access_blocked | パブリックアクセスのブロック状態 |
| object_ownership | オブジェクト所有権設定 |
| bucket_acl | バケットACL設定 |

### ライフサイクル管理情報

| 名前 | 説明 |
|------|------|
| lifecycle_management_enabled | ライフサイクル管理の有効化状態 |
| object_expiration_enabled | オブジェクト自動削除の有効化状態 |
| lifecycle_settings | ライフサイクル設定 |

### アクセスログ情報

| 名前 | 説明 |
|------|------|
| access_logging_enabled | アクセスログの有効化状態 |
| access_logs_bucket_id | アクセスログ用バケットのID |
| access_logs_bucket_arn | アクセスログ用バケットのARN |

### インベントリ情報

| 名前 | 説明 |
|------|------|
| inventory_enabled | インベントリの有効化状態 |
| inventory_bucket_id | インベントリ用バケットのID |
| inventory_bucket_arn | インベントリ用バケットのARN |

### インテリジェントティアリング情報

| 名前 | 説明 |
|------|------|
| intelligent_tiering_enabled | インテリジェントティアリングの有効化状態 |
| tiering_settings | インテリジェントティアリング設定 |

### CloudFront統合情報

| 名前 | 説明 |
|------|------|
| cloudfront_integration_enabled | CloudFront統合の有効化状態 |
| bucket_policy_created | バケットポリシーが作成されたかどうか |

### サマリー出力

| 名前 | 説明 |
|------|------|
| module_summary | S3モジュールの設定サマリー |
| security_features | 有効化されているセキュリティ機能 |

## セキュリティ機能

### 暗号化

- **サーバーサイド暗号化**: AES256またはKMS
- **バケットキー**: パフォーマンス向上
- **転送中暗号化**: HTTPS強制

### アクセス制御

- **パブリックアクセスブロック**: 完全なプライベート設定
- **バケットポリシー**: 最小権限の原則
- **オブジェクト所有権**: 一貫した所有権管理

### データ保護

- **バージョニング**: データの履歴保持
- **MFA削除**: 誤削除防止
- **ライフサイクル管理**: 自動的なデータ管理

## ベストプラクティス

### セキュリティ

1. **暗号化**: 常にサーバーサイド暗号化を有効化
2. **アクセス制御**: パブリックアクセスをブロック
3. **バージョニング**: 重要なデータのバージョニング有効化
4. **MFA削除**: 本番環境でのMFA削除有効化
5. **監査ログ**: アクセスログの有効化

### コスト最適化

1. **ライフサイクル管理**: 適切なストレージクラス移行
2. **インテリジェントティアリング**: 自動的なコスト最適化
3. **不完全アップロード削除**: 不要なコスト削減
4. **オブジェクト削除**: 古いデータの自動削除

### 監視

1. **アクセスログ**: トラフィック分析
2. **インベントリ**: オブジェクト管理
3. **CloudWatch統合**: メトリクス収集
4. **アラーム設定**: 異常検知

## 料金への影響

### 追加料金が発生する機能

- **バージョニング**: ストレージ料金の増加
- **アクセスログ**: 追加のストレージ料金
- **インベントリ**: 処理料金
- **インテリジェントティアリング**: 管理料金

### 料金最適化のヒント

1. **ライフサイクル管理**: 適切なストレージクラス移行
2. **オブジェクト削除**: 不要なデータの削除
3. **インテリジェントティアリング**: 自動的なコスト最適化
4. **アクセスログ**: 必要最小限の保持期間

## トラブルシューティング

### よくある問題

1. **バケット名重複**: グローバルで一意である必要
2. **アクセス拒否**: パブリックアクセスブロックの確認
3. **暗号化エラー**: KMS権限の確認
4. **CloudFront統合エラー**: バケットポリシーの確認

### 解決方法

1. バケット名の一意性確認
2. パブリックアクセス設定の確認
3. IAMロールとKMS権限の確認
4. バケットポリシーの設定確認

## 注意事項

- **バケット名**: グローバルで一意である必要
- **暗号化**: 既存オブジェクトには適用されない
- **ライフサイクル**: 既存オブジェクトに適用される
- **コスト**: 使用量に応じた料金発生
- **セキュリティ**: 定期的な監査の実施

## 更新履歴

### v2.0.0 (最新)
- ベストプラクティスに基づくリファクタリング
- セキュリティ機能の強化
- ライフサイクル管理の追加
- 監視・ログ機能の追加
- コスト最適化機能の追加 