# AWS Terraform WordPress IaC構築

## 概要

AWS上にTerraformを用いてWordPressブログ環境をIaCとして構築し、インフラの自動化（効率化）について学習するプロジェクトです。本番環境と検証環境を分離し、GitHub Actionsによる自動デプロイメントシステムを実装することで、安全で効率的な運用を実現しています。

## 🚀 新機能: GitHub Actions自動化

このプロジェクトは、従来のシェルスクリプトから**GitHub Actionsワークフロー**への移行を完了しました。

### ✅ 移行完了機能
- **WordPress環境構築** - Ansibleによる自動設定
- **自動デプロイメント** - 検証環境から本番環境への安全な反映
- **ロールバック機能** - 問題発生時の迅速な復旧
- **検証環境管理** - コスト最適化された検証環境
- **SSH許可IP更新** - セキュリティの自動化

### 📋 ドキュメント
詳細な使用方法については、[docs/](./docs/)ディレクトリを参照してください：
- [WordPress自動デプロイメント手順書](./docs/WordPress自動デプロイメント手順書_統合版.md)
- [WordPress運用手順書](./docs/WordPress運用手順書_統合版.md)
- [検証環境運用ガイド](./docs/検証環境運用ガイド_統合版.md)

## セットアップ手順

### 1. リポジトリのクローン
```bash
git clone <repository-url>
cd aws-terraform
```

### 2. 設定ファイルの準備
```bash
# terraform.tfvarsの設定
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集して適切な値を設定

# deployment_config.jsonの設定
cp deployment_config.example.json deployment_config.json
# deployment_config.jsonを編集して適切な値を設定
```

#### 自動リソース名生成機能
プロジェクト名（`var.project`）を設定すると、以下のリソース名が自動的に生成されます：

- **EC2名**: `${var.project}-ec2`（例: `my-project-ec2`）
- **検証用EC2名**: `${var.project}-test-ec2`（例: `my-project-test-ec2`）
- **RDS識別子**: `${var.project}-rds`（例: `my-project-rds`）
- **S3バケット名**: `${var.project}-s3`（例: `my-project-s3`）

**使用方法**:
```bash
# 自動生成を使用する場合（推奨）
project = "my-project"
ec2_name = ""           # 自動生成: my-project-ec2
rds_identifier = ""     # 自動生成: my-project-rds
s3_bucket_name = ""     # 自動生成: my-project-s3

# 手動で指定する場合
project = "my-project"
ec2_name = "my-custom-ec2"      # 手動指定: my-custom-ec2
rds_identifier = "my-db"        # 手動指定: my-db
s3_bucket_name = "my-bucket"    # 手動指定: my-bucket
```

### 3. AWS認証情報の設定
```bash
aws configure
# AWS Access Key ID, Secret Access Key, Region, Output formatを入力
```

### 4. Terraformの初期化
```bash
terraform init
```

### 5. インフラのデプロイ
```bash
terraform plan
terraform apply
```

## 目的

* Terraformを用いたAWSインフラ構築について学ぶ
* IaCのベストプラクティスについて学ぶ(モジュール化、変数管理など)
* 複数のAWSサービスをIaCで連携させる
* WordPressの自動デプロイと初期設定の自動化を体験
* 検証環境でのテスト後に本番環境への安全な反映を実現
* 自身のポートフォリオとしての活用

## システム構成

```
+--------------------+
|  Route53     | ← 独自ドメイン管理（example.com）
+--------------------+
      |
      ▼
+--------------------+
|  CloudFront    | ← 静的ファイル配信 / HTTPS (ACM) [一時的に無効化]
+--------------------+
      |
      ▼
  +--------------------------+
  |     S3       | ← 画像ファイル・ログ保存（限定公開）
  +--------------------------+
  +-----------------------------------------------+
  |         VPC (CIDR: 10.0.0.0/16)    |
  |-----------------------------------------------|
  | Public Subnet (10.0.1.0/24)         |
  |  + EC2 NATインスタンス（t3.nano）       |
  |  + EC2 WordPress本番（t2.micro）       |
  |-----------------------------------------------|
  | Private Subnet (10.0.2.0/24)         |
  |  + RDS MySQL（db.t3.micro）          |
  |  + 検証用EC2（※基本停止）          |
  |-----------------------------------------------|
  | IGW（Internet Gateway）           |
  | NATルート（NATインスタンス経由）        |
  +-----------------------------------------------+
```

## GitHub Actions自動化

このプロジェクトは、従来のシェルスクリプトからGitHub Actionsへの移行を完了しました。これにより、より安全で効率的な自動化が実現されています。

### 利用可能なワークフロー

#### 1. WordPress Environment Setup
- **目的**: WordPress環境の構築と設定
- **トリガー**: 手動実行、Ansibleファイルの変更
- **機能**: 
  - インベントリの自動生成
  - 接続テスト
  - Ansibleプレイブックの実行
  - WordPressサイトの動作確認

#### 2. Auto Deployment
- **目的**: 検証環境でのテスト後に本番環境への自動デプロイ
- **トリガー**: WordPressコンテンツの変更、手動実行
- **機能**:
  - 本番環境のスナップショット作成
  - 検証環境の起動と復元
  - 検証環境でのテスト実行
  - 承認フロー（手動/自動）
  - 本番環境への反映
  - 検証環境のクリーンアップ

#### 3. Rollback Deployment
- **目的**: 問題発生時の本番環境のロールバック
- **トリガー**: 手動実行
- **機能**:
  - ロールバック前のバックアップ作成
  - 指定したスナップショットからの復元
  - ロールバック後の動作確認
  - 承認フロー（手動/自動）

### 使用方法

#### GitHub Actionsでの実行
1. **手動実行**: GitHubリポジトリのActionsタブから実行
2. **自動実行**: コードプッシュ時に自動実行
3. **承認フロー**: 設定に応じて手動承認が必要

#### 設定が必要なSecrets
詳細は [GitHub Secrets設定ガイド](.github/GITHUB_SECRETS_SETUP.md) を参照してください。

### 従来のスクリプト（非推奨）

以下のスクリプトは、GitHub Actionsへの移行により非推奨となりました：

```bash
# 非推奨: 従来のシェルスクリプト
./scripts/deployment/auto_deployment.sh
./scripts/maintenance/rollback.sh
./ansible/run_wordpress_setup.sh
```

**推奨**: GitHub Actionsワークフローを使用してください。

## 構成の意図と工夫した点

### 1. ネットワーク基盤の設計

**工夫点:**
- **VPC分離**: 独立したネットワーク空間を確保し、セキュリティを向上
- **サブネット分離**: パブリック/プライベートサブネットで役割を明確に分離
- **NATインスタンス**: NAT Gatewayの代わりにt3.nanoインスタンスを使用し、コスト削減を実現
- **マルチAZ構成**: RDSを2つのAZに配置し、可用性を確保

### 2. セキュリティ設計

**工夫点:**
- **最小権限の原則**: セキュリティグループで必要最小限の通信のみ許可
- **プライベートサブネット**: RDSをプライベートサブネットに配置し、直接アクセスを遮断
- **SSH鍵自動生成**: RSA鍵を自動生成し、セキュアなアクセスを実現
- **ACM証明書**: HTTPS通信の自動化

### 3. モジュール化設計

**工夫点:**
- **再利用性**: 各AWSリソースを個別モジュールとして分離
- **保守性**: モジュール単位での更新・修正が可能
- **可読性**: 明確な責任分離でコードの理解を促進

## 自動化箇所

### 1. インフラ自動化（Terraform）
- **VPC・サブネット**: ネットワーク基盤の自動構築
- **EC2・RDS**: サーバー・データベースの自動プロビジョニング
- **セキュリティグループ**: 通信制御の自動設定
- **Route53・ACM**: ドメイン管理・SSL証明書の自動化

### 2. アプリケーション自動化（Ansible）
- **WordPress設定**: UserDataからAnsibleへの移行により柔軟な設定管理
- **段階的デプロイ**: タグ付きで段階的な環境構築が可能
- **環境別管理**: 本番/開発環境の設定分離

### 3. デプロイメント自動化
- **自動デプロイメント**: 検証環境でのテスト後に本番環境への自動反映
- **スナップショット管理**: 安全な更新プロセスの実現
- **ロールバック機能**: 問題発生時の自動復旧

## コスト最適化とベストプラクティス

### 1. コスト最適化
- **NATインスタンス**: NAT Gatewayの代わりにt3.nanoを使用
- **検証環境**: 基本停止状態でコストを最小化
- **インスタンスタイプ**: 必要最小限のスペックで運用
- **S3ライフサイクル**: 古いログファイルの自動削除

### 2. IaCベストプラクティス
- **モジュール化**: 再利用可能なコンポーネント設計
- **変数管理**: 環境別設定の外部化
- **状態管理**: Terraform stateの適切な管理
- **バージョン管理**: コードの変更履歴を追跡

### 3. 運用ベストプラクティス
- **検証環境**: 本番環境への影響を最小化
- **自動化**: 人的ミスの削減
- **監視**: ログとメトリクスの収集
- **バックアップ**: 定期的なスナップショット作成

## セキュリティ対策

### 1. ネットワークセキュリティ
- **VPC分離**: 独立したネットワーク環境
- **セキュリティグループ**: 最小権限での通信制御
- **プライベートサブネット**: データベースの直接アクセス遮断

### 2. アクセス制御
- **SSH鍵管理**: 自動生成されたRSA鍵による安全なアクセス
- **IAMロール**: 最小権限でのAWSリソースアクセス
- **セキュリティグループ**: 役割別の通信制御

### 3. データ保護
- **RDS暗号化**: 保存時・転送時の暗号化
- **S3暗号化**: オブジェクトレベルの暗号化
- **SSL/TLS**: HTTPS通信の強制

## 改善余地と今後の展望

### 1. 短期的改善
- **CloudFront有効化**: CDN機能の復活によるパフォーマンス向上
- **監視強化**: CloudWatchアラームの追加
- **ログ管理**: 集中ログ管理システムの導入

### 2. 中期的改善
- **コンテナ化**: Docker/Kubernetesへの移行検討
- **CI/CD強化**: GitHub Actionsとの連携
- **マルチリージョン**: 災害対策の強化

### 3. 長期的展望
- **サーバーレス**: Lambda + API Gatewayへの移行
- **AI/ML統合**: 自動スケーリング・異常検知の実装

## 使用方法

### 1. 初期セットアップ
```bash
# 設定ファイル生成
./manage.sh config example.com 20240101

# Terraformの初期化
terraform init

# インフラの構築
terraform plan
terraform apply
```

### 2. WordPress設定
```bash
# Ansibleの実行
cd ansible
python3 generate_inventory.py
ansible-playbook playbooks/wordpress_setup.yml
```

### 3. 自動デプロイメント
```bash
# デプロイメントシステムの初期化
./manage.sh validate

# 自動デプロイメントの実行
./manage.sh deploy production
```

## 技術スタック

- **IaC**: Terraform
- **設定管理**: Ansible
- **Webサーバー**: Apache
- **データベース**: MySQL (RDS)
- **言語**: PHP
- **CMS**: WordPress
- **クラウド**: AWS
- **監視**: CloudWatch （予定）
- **CI/CD**: GitHub Actions（予定）

## セキュリティに関する重要な注意事項

### 機密情報の管理
- **terraform.tfvars**: 機密情報を含むため、Gitにコミットしないでください
- **deployment_config.json**: プロジェクト固有の設定を含むため、Gitにコミットしないでください
- **SSH鍵**: 秘密鍵は絶対にGitにコミットしないでください

### 本番環境での使用前の確認事項
1. **SSH許可IPの制限**: `ssh_allowed_cidr`を特定のIPレンジに制限してください
2. **強力なパスワード**: データベースパスワードを強力なものに変更してください
3. **ドメイン設定**: 実際のドメイン名に変更してください
4. **セキュリティグループ**: 必要最小限のポートのみ開放してください

### 推奨設定
```bash
# セキュリティ強化のための設定例
ssh_allowed_cidr = "203.0.113.0/24"  # 特定のIPレンジ
db_password = "your-very-secure-password-here"
domain_name = "example.com"
```

## ライセンス

このプロジェクトは学習目的で作成されており、個人利用を想定しています。
