# Scripts Directory

このディレクトリには、WordPress AWS環境の自動化スクリプトが含まれています。使用シーンごとにフォルダ分けされています。

## 📁 フォルダ構成

scripts/
├── setup/                    # 初期設定スクリプト
│   ├── terraform_config.sh   # Terraform設定管理
│   └── setup_deployment.sh   # デプロイメント環境初期設定
├── deployment/               # デプロイメントスクリプト
│   ├── prepare_validation.sh # 検証環境準備
│   ├── deploy_to_production.sh # 本番環境反映
│   └── auto_deployment.sh   # 自動デプロイメント
├── maintenance/              # メンテナンススクリプト
│   ├── update_ssh_cidr_env.sh # SSH許可IP更新
│   └── rollback.sh          # ロールバック
└── README.md                # 詳細な説明書

### 🏗️ setup/ - 初期設定スクリプト
Terraform plan/apply前に実行するスクリプト

### 🔄 deployment/ - デプロイメントスクリプト
運用中に実行するデプロイメント関連スクリプト

### 🔧 maintenance/ - メンテナンススクリプト
運用中のメンテナンス作業用スクリプト

## 🏗️ setup/ - 初期設定スクリプト

### terraform_config.sh
**使用シーン**: 新規環境構築時、設定変更時
**使用用途**: Terraform設定ファイルの生成・更新
**動作解説**:
- 対話形式でドメイン名、スナップショット日付、SSH許可IP、検証環境設定、登録者情報を入力
- 既存ドメインの自動検出（Terraform state + AWS CLI）
- `terraform.tfvars`と`deployment_config.json`の生成
- ドメイン登録の確認プロンプト（y/N）

**使用方法**:
```bash
# 新規設定ファイル生成
./setup/terraform_config.sh

# 既存設定の更新
./setup/terraform_config.sh --update-only
```

**注意点**:
- ドメイン登録には料金が発生（年間約$12-15）
- 本番環境ではSSH許可IPを特定IPに制限すること

### setup_deployment.sh
**使用シーン**: デプロイメント環境の初期設定時
**使用用途**: デプロイメントシステムの初期設定
**動作解説**:
- 必要なツール（jq、AWS CLI、MySQL）のインストール
- SSH鍵の設定
- AWS認証情報の確認
- スクリプトの実行権限付与

**使用方法**:
```bash
./setup/setup_deployment.sh
```

**注意点**:
- 初回実行時のみ必要
- sudo権限が必要な場合がある

## 🔄 deployment/ - デプロイメントスクリプト

### prepare_validation.sh
**使用シーン**: 記事更新、プラグイン更新、テーマ変更前
**使用用途**: 検証環境の準備
**動作解説**:
- 本番環境のスナップショット作成
- 検証用EC2/RDSの起動
- 検証環境でのテスト実行
- 本番環境への影響なし

**使用方法**:
```bash
./deployment/prepare_validation.sh
```

**注意点**:
- 検証環境の起動にはコストが発生
- テスト完了後は検証環境を停止すること

### deploy_to_production.sh
**使用シーン**: 検証環境でのテスト完了後
**使用用途**: 本番環境への反映
**動作解説**:
- 検証環境の状態確認
- 本番環境のバックアップ作成
- 検証環境から本番環境へのデータ同期
- 本番環境の動作確認
- 検証環境の停止

**使用方法**:
```bash
./deployment/deploy_to_production.sh
```

**注意点**:
- 本番環境が一時的に停止する可能性
- 必ず検証環境でのテスト完了後に実行

### auto_deployment.sh
**使用シーン**: 一連のデプロイメント作業の自動化
**使用用途**: 検証環境準備から本番反映までの自動化
**動作解説**:
- `prepare_validation.sh`の実行
- ユーザー確認
- `deploy_to_production.sh`の実行
- 完了確認

**使用方法**:
```bash
./deployment/auto_deployment.sh
```

**注意点**:
- 途中で確認が必要な場合は停止
- すべての作業がログに記録される

## 🔧 maintenance/ - メンテナンススクリプト

### update_ssh_cidr_env.sh
**使用シーン**: SSH許可IPの変更時
**使用用途**: SSH接続許可IPの更新
**動作解説**:
- 環境変数`SSH_ALLOWED_IP`からIPアドレスを取得
- CIDR形式に変換
- `terraform.tfvars`の更新
- Terraform planの実行

**使用方法**:
```bash
export SSH_ALLOWED_IP=your.ip.address.here
./maintenance/update_ssh_cidr_env.sh
```

**注意点**:
- 環境変数の設定が必要
- セキュリティ強化のため特定IPに制限すること

### rollback.sh
**使用シーン**: デプロイメント失敗時、緊急時
**使用用途**: 本番環境のロールバック
**動作解説**:
- 最新スナップショットの自動検出
- 本番環境の停止
- スナップショットからの復元
- WordPressファイルの復元
- 動作確認

**使用方法**:
```bash
./maintenance/rollback.sh
```

**注意点**:
- 本番環境が一時的に停止
- 最新のスナップショットを使用
- 緊急時以外は使用を避ける

## 📋 運用フロー

### 初回セットアップ
```bash
# 1. 初期設定
./setup/terraform_config.sh
./setup/setup_deployment.sh

# 2. Terraform実行
terraform plan
terraform apply

# 3. 設定ファイルの更新
# deployment_config.jsonの値を設定
```

### 日常的な運用
```bash
# 1. 検証環境の準備
./deployment/prepare_validation.sh

# 2. 検証環境でのテスト
# ブラウザで検証環境にアクセス

# 3. 本番環境への反映
./deployment/deploy_to_production.sh

# 4. 緊急時のみロールバック
./maintenance/rollback.sh
```

### 自動化された運用
```bash
# 一連の作業を自動化
./deployment/auto_deployment.sh
```

## ⚠️ 注意事項

### セキュリティ
- 本番環境では必ずSSH許可IPを特定IPに制限
- AWS認証情報の適切な管理
- 最小権限の原則に従ったIAM設定

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
./setup/terraform_config.sh
```

#### 権限エラー
```bash
chmod +x scripts/*/*.sh
```

---

*このドキュメントは随時更新されます。最新版を確認してから作業を開始してください。* 