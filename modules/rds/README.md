# RDS Module

このモジュールは、AWS RDSインスタンスを作成し、WordPress環境のデータベース基盤を提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 特徴

- **セキュリティ強化**: 暗号化、削除保護、IAM認証対応
- **柔軟なバックアップ設定**: カスタマイズ可能なバックアップ期間と時間帯
- **監視・ログ機能**: CloudWatchログ、Performance Insights、詳細モニタリング対応
- **マルチAZ対応**: 高可用性のためのマルチAZ配置
- **詳細なタグ管理**: リソース管理のための包括的なタグ付け

## 使用方法

### 基本的な使用例

```hcl
module "rds" {
  source = "./modules/rds"
  
  project = "my-wordpress"
  
  private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
  rds_security_group_id = "sg-12345678"
  
  db_password = "secure-password-123"
  snapshot_date = "20240727"
  rds_identifier = "my-wordpress-db"
}
```

### 高度な設定例

```hcl
module "rds" {
  source = "./modules/rds"
  
  project     = "my-wordpress"
  environment = "production"
  
  private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
  rds_security_group_id = "sg-12345678"
  
  # データベース設定
  db_instance_class = "db.t3.micro"
  allocated_storage = 50
  max_allocated_storage = 200
  storage_type = "gp3"
  
  db_name = "wordpress"
  db_username = "admin"
  db_password = "secure-password-123"
  
  # セキュリティ設定
  deletion_protection = true
  storage_encrypted = true
  publicly_accessible = false
  multi_az = true
  
  # バックアップ設定
  backup_retention_period = 7
  backup_window = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"
  
  # 監視・ログ設定
  enable_cloudwatch_logs = true
  enable_performance_insights = true
  enable_enhanced_monitoring = true
  monitoring_interval = 60
  
  # パラメータ設定
  parameter_group_family = "mysql8.0"
  db_parameters = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    }
  ]
  
  # 検証環境設定
  enable_validation_rds = true
  validation_rds_snapshot_identifier = "my-wordpress-snapshot"
  
  # タグ設定
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "true"
  }
}
```

## 入力変数

### 基本設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| project | プロジェクト名 | `string` | - | はい |
| environment | 環境名 | `string` | `"production"` | いいえ |
| private_subnet_ids | プライベートサブネットのID一覧 | `list(string)` | - | はい |
| rds_security_group_id | RDS用セキュリティグループのID | `string` | - | はい |
| db_instance_class | RDSインスタンスタイプ | `string` | `"db.t3.micro"` | いいえ |
| allocated_storage | 割り当てストレージサイズ（GB） | `number` | `20` | いいえ |
| max_allocated_storage | 自動拡張の最大ストレージサイズ（GB） | `number` | `100` | いいえ |
| storage_type | ストレージタイプ | `string` | `"gp2"` | いいえ |
| db_name | データベース名 | `string` | `"wordpress"` | いいえ |
| db_username | データベースマスターユーザー名 | `string` | `"admin"` | いいえ |
| db_password | データベースマスターパスワード | `string` | - | はい |
| snapshot_date | スナップショット識別子用の日付 | `string` | - | はい |
| rds_identifier | RDSインスタンスの識別子 | `string` | - | はい |

### セキュリティ設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| deletion_protection | 削除保護の有効化 | `bool` | `false` | いいえ |
| storage_encrypted | ストレージ暗号化の有効化 | `bool` | `true` | いいえ |
| kms_key_id | KMSキーID（暗号化用） | `string` | `""` | いいえ |
| publicly_accessible | パブリックアクセスの有効化 | `bool` | `false` | いいえ |
| multi_az | マルチAZ配置の有効化 | `bool` | `false` | いいえ |

### バックアップ設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| backup_retention_period | バックアップ保持期間（日） | `number` | `7` | いいえ |
| backup_window | バックアップ時間帯 | `string` | `"03:00-04:00"` | いいえ |
| maintenance_window | メンテナンス時間帯 | `string` | `"sun:04:00-sun:05:00"` | いいえ |

### 監視・ログ設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| enable_cloudwatch_logs | CloudWatchログの有効化 | `bool` | `false` | いいえ |
| enable_performance_insights | Performance Insightsの有効化 | `bool` | `false` | いいえ |
| performance_insights_retention_period | Performance Insights保持期間（日） | `number` | `7` | いいえ |
| enable_enhanced_monitoring | 詳細モニタリングの有効化 | `bool` | `false` | いいえ |
| monitoring_interval | モニタリング間隔（秒） | `number` | `60` | いいえ |

### 検証環境設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| enable_validation_rds | 検証用RDSインスタンスの作成有無 | `bool` | `false` | いいえ |
| validation_rds_snapshot_identifier | 検証用RDSのスナップショット識別子 | `string` | `""` | いいえ |

### パラメータ設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| parameter_group_family | パラメータグループファミリー | `string` | `"mysql8.0"` | いいえ |
| db_parameters | データベースパラメータ | `list(object)` | デフォルト値 | いいえ |

### タグ設定

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| tags | 追加のタグ | `map(string)` | `{}` | いいえ |

## 出力

### 本番環境

| 名前 | 説明 |
|------|------|
| db_endpoint | RDSエンドポイント（アプリケーションからの接続先） |
| db_port | RDSポート番号 |
| db_name | 作成したデータベース名 |
| db_username | DBマスターユーザー名 |
| db_identifier | RDSインスタンス識別子 |
| db_arn | RDSインスタンスのARN |
| db_status | RDSインスタンスのステータス |
| db_subnet_group_name | DBサブネットグループ名 |
| db_parameter_group_name | DBパラメータグループ名 |
| db_availability_zone | RDSインスタンスのアベイラビリティゾーン |
| db_multi_az | マルチAZ配置の有効化状態 |
| db_storage_encrypted | ストレージ暗号化の有効化状態 |
| db_backup_retention_period | バックアップ保持期間 |
| db_performance_insights_enabled | Performance Insightsの有効化状態 |

### 検証環境

| 名前 | 説明 |
|------|------|
| validation_db_endpoint | 検証用RDSエンドポイント |
| validation_db_port | 検証用RDSポート番号 |
| validation_db_name | 検証用RDSのデータベース名 |
| validation_db_identifier | 検証用RDSインスタンス識別子 |
| validation_db_arn | 検証用RDSインスタンスのARN |
| validation_db_status | 検証用RDSインスタンスのステータス |

### 監視・ログ

| 名前 | 説明 |
|------|------|
| cloudwatch_logs_enabled | CloudWatchログの有効化状態 |
| performance_insights_enabled | Performance Insightsの有効化状態 |
| enhanced_monitoring_enabled | 詳細モニタリングの有効化状態 |

## セキュリティ機能

### 暗号化

- **ストレージ暗号化**: デフォルトで有効
- **KMS暗号化**: カスタムKMSキー対応
- **転送中暗号化**: SSL/TLS接続

### アクセス制御

- **削除保護**: 本番環境での誤削除防止
- **パブリックアクセス**: デフォルトで無効
- **セキュリティグループ**: VPC内からのアクセスのみ許可

### 監査・ログ

- **CloudWatchログ**: MySQLログとエラーログ
- **Performance Insights**: データベースパフォーマンス監視
- **詳細モニタリング**: OSレベルのメトリクス

## ベストプラクティス

### セキュリティ

1. **削除保護**: 本番環境では必ず有効化
2. **暗号化**: ストレージと転送中の暗号化を有効化
3. **パブリックアクセス**: プライベートサブネットでの配置
4. **強力なパスワード**: 複雑なパスワードの使用

### パフォーマンス

1. **インスタンスタイプ**: ワークロードに適したサイズ選択
2. **ストレージタイプ**: 用途に応じてgp2/gp3/io1選択
3. **自動拡張**: 適切な最大サイズ設定
4. **パラメータチューニング**: アプリケーションに最適化

### 可用性

1. **マルチAZ**: 本番環境での高可用性
2. **バックアップ**: 適切な保持期間設定
3. **メンテナンス時間**: 業務時間外での設定

### 監視

1. **CloudWatchログ**: データベースログの収集
2. **Performance Insights**: パフォーマンス問題の特定
3. **アラーム設定**: 重要なメトリクスの監視

## 料金への影響

### 追加料金が発生する機能

- **Performance Insights**: 約$0.10/DB時間
- **CloudWatchログ**: 約$0.50/GB/月
- **詳細モニタリング**: 約$0.10/DB時間
- **マルチAZ**: 約2倍の料金

### 料金最適化のヒント

1. **検証環境**: 最小限の機能でコスト削減
2. **インスタンスサイズ**: 適切なサイズ選択
3. **バックアップ期間**: 必要最小限の保持期間
4. **監視機能**: 必要な機能のみ有効化

## トラブルシューティング

### よくある問題

1. **接続エラー**: セキュリティグループの設定確認
2. **パフォーマンス問題**: インスタンスタイプとストレージの見直し
3. **バックアップ失敗**: ストレージ容量の確認
4. **暗号化エラー**: KMSキーの権限確認

### 解決方法

1. セキュリティグループのインバウンドルール確認
2. CloudWatchメトリクスでのパフォーマンス分析
3. ストレージ自動拡張の設定確認
4. IAMロールとKMS権限の確認

## 注意事項

- **パスワード**: 機密情報として適切に管理
- **スナップショット**: 定期的なバックアップテスト
- **メンテナンス**: 計画的なメンテナンス時間設定
- **コスト**: 監視機能の使用量に注意 