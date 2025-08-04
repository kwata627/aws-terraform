# SSH Module

このモジュールはSSHキーペアを作成し、セキュアなSSHアクセスを提供します。セキュリティ強化と監視機能を考慮した設計となっています。

## 特徴

- セキュアな鍵生成（RSA/ECDSA）
- 鍵の自動ローテーション
- バックアップ機能
- 監査ログ機能
- 詳細なタグ管理

## ファイル構成

```
modules/ssh/
├── main.tf              # メイン設定（プロバイダー設定）
├── variables.tf         # 変数定義
├── outputs.tf          # 出力定義
├── locals.tf           # ローカル値定義
├── data.tf            # データソース
├── ssh-keys.tf        # SSHキーペア定義
└── README.md          # このファイル
```

## 使用方法

### 基本的な使用例

```hcl
module "ssh" {
  source = "./modules/ssh"
  
  project = "my-project"
  environment = "production"
}
```

### セキュリティ機能を有効化した使用例

```hcl
module "ssh" {
  source = "./modules/ssh"
  
  project = "my-project"
  environment = "production"
  
  # セキュリティ機能
  enable_key_rotation = true
  key_rotation_days = 90
  
  enable_backup = true
  backup_retention_days = 30
  
  enable_audit_logs = true
  audit_retention_days = 90
  
  # 鍵設定
  key_algorithm = "RSA"
  rsa_bits = 4096
}
```

### ECDSAキーを使用した例

```hcl
module "ssh" {
  source = "./modules/ssh"
  
  project = "my-project"
  environment = "production"
  
  key_algorithm = "ECDSA"
  ecdsa_curve = "P256"
}
```

## 作成されるリソース

### 必須リソース

1. **TLS Private Key**
   - 指定されたアルゴリズムで秘密鍵を生成
   - RSA: 2048, 3072, 4096ビット
   - ECDSA: P224, P256, P384, P521曲線

2. **AWS Key Pair**
   - AWSで管理されるSSHキーペア
   - 適切なタグ付け

### オプションリソース

3. **S3 Backup Bucket** (オプション)
   - SSHキーのバックアップ用S3バケット
   - バージョニングと暗号化
   - ライフサイクル管理

4. **CloudWatch Log Group** (オプション)
   - SSHキー監査ログ用
   - 設定可能な保持期間

5. **IAM Role for Rotation** (オプション)
   - SSHキーローテーション用IAMロール
   - 必要な権限を付与

## セキュリティ機能

### 鍵ローテーション

- 自動的な鍵の更新
- 設定可能なローテーション間隔
- 安全な鍵の置き換え

### バックアップ機能

- S3バケットでの鍵のバックアップ
- 暗号化されたストレージ
- ライフサイクル管理

### 監査ログ

- CloudWatch Logsでの監査
- 鍵の使用状況の追跡
- セキュリティイベントの記録

## 変数

### 必須変数

- `project`: プロジェクト名

### オプション変数

- `environment`: 環境名（デフォルト: "production"）
- `key_name_suffix`: キー名サフィックス（デフォルト: "ssh-key"）
- `key_algorithm`: 鍵アルゴリズム（デフォルト: "RSA"）
- `rsa_bits`: RSAビット数（デフォルト: 4096）
- `ecdsa_curve`: ECDSA曲線（デフォルト: "P256"）
- `enable_key_rotation`: 鍵ローテーションの有効化
- `enable_backup`: バックアップ機能の有効化
- `enable_audit_logs`: 監査ログの有効化
- `tags`: 追加のタグ

## 出力

### SSHキー情報

- `key_name`: SSHキーペア名
- `key_id`: SSHキーペアID
- `key_fingerprint`: キーフィンガープリント
- `key_arn`: キーのARN

### SSHキー内容

- `private_key_pem`: 秘密鍵（PEM形式）
- `public_key_openssh`: 公開鍵（OpenSSH形式）
- `public_key_pem`: 公開鍵（PEM形式）

### 設定情報

- `key_algorithm`: 使用されたアルゴリズム
- `key_size`: 鍵のサイズ

### セキュリティ機能

- `backup_bucket_name`: バックアップバケット名
- `audit_log_group_name`: 監査ロググループ名
- `rotation_role_arn`: ローテーションロールARN
- `security_features_enabled`: 有効化された機能
- `security_config`: セキュリティ設定
- `module_summary`: モジュールサマリー

## セキュリティベストプラクティス

1. **強力な鍵の使用**: RSA 4096ビットまたはECDSA P256以上を使用
2. **定期的なローテーション**: 90日ごとの鍵ローテーションを推奨
3. **バックアップの有効化**: 鍵の安全なバックアップを有効化
4. **監査ログの有効化**: 鍵の使用状況を監視
5. **適切なタグ付け**: リソースの管理と追跡

## 注意事項

- 秘密鍵は機密情報として扱い、安全に管理してください
- 本番環境では鍵ローテーション機能の有効化を推奨します
- バックアップ機能は追加コストが発生する可能性があります
- 監査ログはコンプライアンス要件に応じて有効化してください

## トラブルシューティング

### よくある問題

1. **鍵の生成に失敗**
   - アルゴリズムとビット数の組み合わせを確認
   - プロジェクト名の形式を確認

2. **バックアップが作成されない**
   - S3バケットの権限を確認
   - バックアップ機能が有効化されているか確認

3. **監査ログが表示されない**
   - CloudWatch Logsの権限を確認
   - 監査ログ機能が有効化されているか確認

## ライセンス

このモジュールはMITライセンスの下で提供されています。 