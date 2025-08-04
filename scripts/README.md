# Scripts Directory

このディレクトリには、WordPress AWS環境の自動化スクリプトが含まれています。ベストプラクティスに沿った設計で、共通ライブラリを使用した統一されたスクリプト群です。

## 📁 フォルダ構成

```
scripts/
├── lib/                           # 共通ライブラリ
│   └── common.sh                  # 共通関数・ユーティリティ
├── templates/                     # 設定テンプレート
│   └── deployment_config.template.json # デプロイメント設定テンプレート
├── setup/                         # 初期設定スクリプト
│   ├── terraform_config.sh        # Terraform設定管理
│   └── setup_deployment.sh        # デプロイメント環境初期設定
├── deployment/                    # デプロイメントスクリプト
│   ├── prepare_validation.sh      # 検証環境準備
│   ├── deploy_to_production.sh    # 本番環境反映
│   └── auto_deployment.sh         # 自動デプロイメント
├── maintenance/                   # メンテナンススクリプト
│   ├── update_ssh_cidr_env.sh    # SSH許可IP更新
│   └── rollback.sh               # ロールバック
└── README.md                     # 詳細な説明書
```

### 🏗️ lib/ - 共通ライブラリ
すべてのスクリプトで使用される共通機能を提供

### 📋 templates/ - 設定テンプレート
環境変数による設定の柔軟性を提供

### 🏗️ setup/ - 初期設定スクリプト
Terraform plan/apply前に実行するスクリプト

### 🔄 deployment/ - デプロイメントスクリプト
運用中に実行するデプロイメント関連スクリプト

### 🔧 maintenance/ - メンテナンススクリプト
運用中のメンテナンス作業用スクリプト

## 🚀 ベストプラクティス機能

### 共通ライブラリ (lib/common.sh)
- **統一されたログ機能**: 色付きログ、ログレベル制御
- **エラーハンドリング**: 一貫したエラー処理、クリーンアップ
- **設定管理**: JSON設定ファイルの検証・読み込み・更新
- **AWS連携**: 認証情報確認、リソース存在確認
- **ユーティリティ**: バックアップ、権限確認、必須コマンド確認

### 環境変数による設定
```bash
# 基本設定
export DOMAIN_NAME="example.com"
export SNAPSHOT_DATE="20250803"
export SSH_ALLOWED_IP="192.168.1.100"

# AWS設定
export AWS_REGION="ap-northeast-1"
export AWS_PROFILE="default"

# デプロイメント設定
export AUTO_APPROVE="false"
export ROLLBACK_ON_FAILURE="true"
export NOTIFICATION_EMAIL="admin@example.com"
```

## 🏗️ setup/ - 初期設定スクリプト

### terraform_config.sh
**使用シーン**: 新規環境構築時、設定変更時
**使用用途**: Terraform設定ファイルの生成・更新

**機能**:
- 対話形式での設定入力
- 既存ドメインの自動検出（Terraform state + AWS CLI）
- `terraform.tfvars`と`deployment_config.json`の生成
- 環境変数による自動設定
- 設定の検証・バックアップ

**使用方法**:
```bash
# 対話形式での設定
./scripts/setup/terraform_config.sh

# 環境変数による自動設定
export DOMAIN_NAME="example.com"
export SNAPSHOT_DATE="20250803"
export SSH_ALLOWED_IP="192.168.1.100"
./scripts/setup/terraform_config.sh

# 既存設定の更新
./scripts/setup/terraform_config.sh --update-only
```

**注意点**:
- ドメイン登録には料金が発生（年間約$12-15）
- 本番環境ではSSH許可IPを特定IPに制限すること

### setup_deployment.sh
**使用シーン**: デプロイメント環境の初期設定時
**使用用途**: デプロイメントシステムの初期設定

**機能**:
- 必要なツール（jq、AWS CLI、MySQL）のインストール
- SSH鍵の設定
- AWS認証情報の確認
- スクリプトの実行権限付与
- 設定ファイルの初期化

**使用方法**:
```bash
./scripts/setup/setup_deployment.sh
```

## 🔄 deployment/ - デプロイメントスクリプト

### auto_deployment.sh
**使用シーン**: 一連のデプロイメント作業の自動化
**使用用途**: 検証環境準備から本番反映までの自動化

**機能**:
- 本番環境のスナップショット作成
- 検証環境の起動・復元
- 検証環境でのテスト実行
- 本番環境への反映
- 検証環境の停止
- ロールバック機能
- 通知機能

**使用方法**:
```bash
# 通常実行
./scripts/deployment/auto_deployment.sh

# ドライラン（実際の変更なし）
./scripts/deployment/auto_deployment.sh --dry-run
```

**環境変数**:
```bash
export AUTO_APPROVE="false"
export ROLLBACK_ON_FAILURE="true"
export NOTIFICATION_EMAIL="admin@example.com"
export LOG_LEVEL="INFO"
```

### prepare_validation.sh
**使用シーン**: 記事更新、プラグイン更新、テーマ変更前
**使用用途**: 検証環境の準備

**機能**:
- 本番環境のスナップショット作成
- 検証用EC2/RDSの起動
- 検証環境でのテスト実行
- 本番環境への影響なし

### deploy_to_production.sh
**使用シーン**: 検証環境でのテスト完了後
**使用用途**: 本番環境への反映

**機能**:
- 検証環境の状態確認
- 本番環境のバックアップ作成
- 検証環境から本番環境へのデータ同期
- 本番環境の動作確認
- 検証環境の停止

## 🔧 maintenance/ - メンテナンススクリプト

### update_ssh_cidr_env.sh
**使用シーン**: SSH許可IPの変更時
**使用用途**: SSH接続許可IPの更新

**機能**:
- IPアドレス・CIDR形式の検証
- Terraform設定ファイルの更新
- デプロイメント設定ファイルの更新
- Terraform planの実行
- セキュリティ警告の表示

**使用方法**:
```bash
# 環境変数から取得
export SSH_ALLOWED_IP="192.168.1.100"
./scripts/maintenance/update_ssh_cidr_env.sh

# 直接指定
./scripts/maintenance/update_ssh_cidr_env.sh --ip 192.168.1.100
./scripts/maintenance/update_ssh_cidr_env.sh --cidr 192.168.1.0/24

# 自動確認
./scripts/maintenance/update_ssh_cidr_env.sh --ip 192.168.1.100 --auto-confirm
```

### rollback.sh
**使用シーン**: デプロイメント失敗時、緊急時
**使用用途**: 本番環境のロールバック

**機能**:
- 最新スナップショットの自動検出
- 本番環境の停止
- スナップショットからの復元
- WordPressファイルの復元
- 動作確認

## 📋 運用フロー

### 初回セットアップ
```bash
# 1. 初期設定
./scripts/setup/terraform_config.sh
./scripts/setup/setup_deployment.sh

# 2. Terraform実行
terraform plan
terraform apply

# 3. 設定ファイルの更新
# deployment_config.jsonの値を設定
```

### 日常的な運用
```bash
# 1. 検証環境の準備
./scripts/deployment/prepare_validation.sh

# 2. 検証環境でのテスト
# ブラウザで検証環境にアクセス

# 3. 本番環境への反映
./scripts/deployment/deploy_to_production.sh

# 4. 緊急時のみロールバック
./scripts/maintenance/rollback.sh
```

### 自動化された運用
```bash
# 一連の作業を自動化
./scripts/deployment/auto_deployment.sh
```

## ⚠️ 注意事項

### セキュリティ
- 本番環境では必ずSSH許可IPを特定IPに制限
- AWS認証情報の適切な管理
- 最小権限の原則に従ったIAM設定
- 環境変数による機密情報の管理

### コスト管理
- 検証環境は使用後に停止
- 不要なリソースの定期的な確認
- ドメイン登録料金の継続発生に注意

### バックアップ
- デプロイメント前の自動バックアップ
- スナップショットの定期的な確認
- ログファイルの保存

## 🔍 トラブルシューティング

### よくある問題

#### AWS認証情報エラー
```bash
aws sts get-caller-identity
aws configure
```

#### SSH接続エラー
```bash
ls -la ~/.ssh/id_rsa
terraform output -raw ssh_private_key > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

#### 設定ファイルエラー
```bash
cat deployment_config.json
./scripts/setup/terraform_config.sh
```

#### 権限エラー
```bash
chmod +x scripts/*/*.sh
```

#### ログレベルの変更
```bash
export LOG_LEVEL="WARN"  # INFO, WARN, ERROR
./scripts/deployment/auto_deployment.sh
```

## 🎯 ベストプラクティス

### 1. 共通ライブラリの活用
- すべてのスクリプトで`lib/common.sh`を使用
- 統一されたログ・エラーハンドリング
- 設定管理の標準化

### 2. 環境変数による設定
- ハードコードの回避
- CI/CD環境での自動化対応
- セキュリティの向上

### 3. エラーハンドリング
- 適切なエラー終了コード
- クリーンアップ処理
- ロールバック機能

### 4. ログ管理
- 構造化されたログ出力
- ログレベルの制御
- ファイル・コンソール両方への出力

### 5. 設定検証
- JSON形式の検証
- 必須項目の確認
- デフォルト値の提供

---

*このドキュメントは随時更新されます。最新版を確認してから作業を開始してください。* 