# Security Module

このモジュールはAWSセキュリティグループを作成し、ネットワークセキュリティを提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 特徴

- 構造化されたセキュリティルール定義
- 動的セキュリティグループ作成
- 最小権限の原則の適用
- セキュリティ監査機能
- 詳細なタグ管理

## ファイル構成

```
modules/security/
├── main.tf              # メイン設定（プロバイダー設定）
├── variables.tf         # 変数定義
├── outputs.tf          # 出力定義
├── locals.tf           # ローカル値定義
├── data.tf            # データソース
├── security-groups.tf  # セキュリティグループ定義
├── audit.tf           # セキュリティ監査機能
└── README.md          # このファイル
```

## 使用方法

### 基本的な使用例

```hcl
module "security" {
  source = "./modules/security"
  
  project     = "my-project"
  environment = "production"
  vpc_id      = "vpc-12345678"
  
  security_rules = {
    ssh = {
      enabled       = true
      allowed_cidrs = ["10.0.0.0/16"]
    }
    http = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    https = {
      enabled       = true
      allowed_cidrs = ["0.0.0.0/0"]
    }
    # ... その他のルール
  }
}
```

### セキュリティ監査機能の有効化

```hcl
module "security" {
  source = "./modules/security"
  
  project     = "my-project"
  environment = "production"
  vpc_id      = "vpc-12345678"
  
  enable_security_audit = true
  security_audit_retention_days = 90
  
  # ... その他の設定
}
```

### セキュリティ監視機能の有効化

```hcl
module "security" {
  source = "./modules/security"
  
  project     = "my-project"
  environment = "production"
  vpc_id      = "vpc-12345678"
  
  enable_security_monitoring = true
  security_monitoring_interval = 30
  security_notification_email = "admin@example.com"
  
  # ... その他の設定
}
```

## 作成されるセキュリティグループ

### 必須セキュリティグループ

1. **EC2 Public Security Group**
   - SSH (22)
   - HTTP (80)
   - HTTPS (443)
   - ICMP

2. **EC2 Private Security Group**
   - SSH from public EC2
   - HTTP (80)
   - HTTPS (443)

3. **RDS Security Group**
   - MySQL (3306) from EC2
   - PostgreSQL (5432) from EC2

4. **NAT Instance Security Group**
   - SSH (22)
   - ICMP

### オプションセキュリティグループ

5. **ALB Security Group** (オプション)
   - HTTP (80)
   - HTTPS (443)

6. **Cache Security Group** (オプション)
   - Redis (6379)
   - Memcached (11211)

## セキュリティ機能

### セキュリティ監査

- CloudWatch Logsによる監査ログ
- IAMロールとポリシー
- セキュリティグループの変更追跡

### セキュリティ監視

- CloudWatchアラーム
- SNS通知
- セキュリティ違反の自動検出

### セキュリティコンプライアンス

- AWS Config設定
- コンプライアンス標準の適用
- セキュリティポリシーの自動化

## 変数

### 必須変数

- `project`: プロジェクト名
- `vpc_id`: VPCのID

### オプション変数

- `environment`: 環境名（デフォルト: "production"）
- `security_rules`: セキュリティルール設定
- `enable_security_audit`: セキュリティ監査の有効化
- `enable_security_monitoring`: セキュリティ監視の有効化
- `tags`: 追加のタグ

## 出力

### セキュリティグループID

- `ec2_public_sg_id`
- `ec2_private_sg_id`
- `rds_sg_id`
- `nat_instance_sg_id`
- `alb_sg_id` (オプション)
- `cache_sg_id` (オプション)

### セキュリティ監査

- `security_audit_log_group_name`
- `security_audit_role_arn`
- `security_audit_role_name`

### セキュリティ設定サマリー

- `security_groups_created`
- `security_rules_enabled`
- `security_features_enabled`
- `module_summary`
- `security_risk_assessment`

## セキュリティベストプラクティス

1. **最小権限の原則**: 必要最小限のポートのみを開放
2. **セキュリティグループの分離**: 用途別にセキュリティグループを分離
3. **監査ログの有効化**: セキュリティ監査機能を有効化
4. **定期的な監視**: セキュリティ監視機能を有効化
5. **タグの活用**: 適切なタグ付けによる管理

## 注意事項

- 本番環境では、SSHアクセスを特定のIPアドレスに制限することを推奨します
- セキュリティ監査機能は追加コストが発生する可能性があります
- セキュリティルールの変更は慎重に行い、影響範囲を確認してください

## トラブルシューティング

### よくある問題

1. **セキュリティグループの作成に失敗**
   - VPC IDが正しいことを確認
   - プロジェクト名が有効な形式であることを確認

2. **セキュリティルールが適用されない**
   - ルールの有効化フラグを確認
   - CIDRブロックの形式を確認

3. **監査ログが表示されない**
   - CloudWatch Logsの権限を確認
   - IAMロールの設定を確認

## ライセンス

このモジュールはMITライセンスの下で提供されています。 