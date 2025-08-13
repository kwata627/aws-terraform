# WordPress Ansible環境

## 概要

このディレクトリには、WordPress環境のAnsible設定が含まれています。ベストプラクティスに沿った設計で、共通ライブラリを使用した統一されたAnsible環境を提供します。UserDataからAnsibleへの移行により、より柔軟で保守性の高いインフラ管理を実現しています。

## 📁 ディレクトリ構成

```
ansible/
├── lib/                           # 共通ライブラリ
│   └── common.sh                  # Ansible用共通関数・ユーティリティ
├── templates/                     # 設定テンプレート
│   └── ansible_config.template.yml # Ansible設定テンプレート
├── roles/                         # Ansibleロール
│   ├── system/                    # システムパッケージ管理
│   ├── apache/                    # Apache Webサーバー
│   ├── php/                       # PHP設定
│   ├── wordpress/                 # WordPress設定
│   ├── security/                  # セキュリティ設定
│   ├── database/                  # データベース接続
│   ├── monitoring/                # 監視・ログ設定
│   └── ssh/                       # SSH設定
├── playbooks/                     # プレイブック
│   ├── wordpress_setup.yml        # メイン設定
│   ├── step_by_step_setup.yml     # 段階的設定
│   └── configure_ssh.yml          # SSH設定
├── group_vars/                    # グループ変数
│   ├── all.yml                    # 全環境共通
│   ├── wordpress.yml              # WordPress用
│   └── nat_instance.yml           # NATインスタンス用
├── environments/                   # 環境別設定
│   ├── production.yml             # 本番環境
│   └── development.yml            # 開発環境
├── scripts/                       # 実行スクリプト
│   ├── deploy.sh                  # デプロイメント
│   └── test_environment.sh        # 環境テスト
├── inventory/                     # インベントリ
│   └── hosts.yml                  # ホスト定義
├── run_wordpress_setup.sh         # メイン実行スクリプト
├── generate_inventory.py          # インベントリ生成スクリプト
├── ansible.cfg                    # Ansible設定ファイル
└── README.md                      # 詳細な説明書
```

### 🏗️ lib/ - 共通ライブラリ
すべてのAnsibleスクリプトで使用される共通機能を提供

### 📋 templates/ - 設定テンプレート
環境変数による設定の柔軟性を提供

## 🚀 ベストプラクティス機能

### 共通ライブラリ (lib/common.sh)
- **統一されたログ機能**: 色付きログ、ログレベル制御
- **エラーハンドリング**: 一貫したエラー処理、クリーンアップ
- **Ansible連携**: 接続テスト、構文チェック、ドライラン
- **Terraform連携**: 出力取得、インベントリ生成
- **設定管理**: YAML/JSON設定ファイルの検証・読み込み・更新

### 環境変数による設定

#### 1. 環境変数ファイルの作成
```bash
# テンプレートをコピー
cp templates/env.template .env

# 実際の値を設定
vim .env

# または、現在の環境の例を参考にする
cp env.example.current .env
```

#### 2. 必須環境変数
```bash
# データベース設定（RDSとWordPressで同じ認証情報を使用）
export WORDPRESS_DB_HOST="your-rds-endpoint:3306"
export WORDPRESS_DB_NAME="wordpress"
export WORDPRESS_DB_USER="your-db-user"        # RDSのユーザー名と同じ
export WORDPRESS_DB_PASSWORD="your-db-password" # RDSのパスワードと同じ

# SSH設定
export SSH_USER="ec2-user"
export SSH_PRIVATE_KEY_FILE="~/.ssh/your-key.pem"

# WordPress設定
export WORDPRESS_DOMAIN="your-domain.com"
export WORDPRESS_LOCALE="ja"
export WORDPRESS_LANGUAGE="ja"
```

#### 3. オプション環境変数
```bash
# PHP設定
export PHP_MEMORY_LIMIT="256M"
export PHP_MAX_EXECUTION_TIME="300"
export PHP_DATE_TIMEZONE="Asia/Tokyo"

# セキュリティ設定
export WORDPRESS_DEBUG="false"
export WORDPRESS_AUTOMATIC_UPDATER_DISABLED="true"

# 監視設定
export MONITORING_ENABLED="true"
export LOG_RETENTION_DAYS="30"
```

## 🏗️ 使用方法

### 1. 基本的な実行

```bash
# インベントリの更新
cd ansible
python3 generate_inventory.py

# 全環境構築
./run_wordpress_setup.sh

# 段階的実行
./run_wordpress_setup.sh --step-by-step

# ドライラン実行
./run_wordpress_setup.sh --dry-run
```

### 2. 環境別デプロイ

```bash
# 本番環境
./run_wordpress_setup.sh --environment production

# 開発環境
./run_wordpress_setup.sh --environment development

# カスタムプレイブック
./run_wordpress_setup.sh --playbook playbooks/step_by_step_setup.yml
```

### 3. 環境変数による自動化

```bash
# 環境変数による設定
export ENVIRONMENT="production"
export DRY_RUN="true"
export LOG_LEVEL="WARN"
./run_wordpress_setup.sh
```

### 4. インベントリ生成の詳細設定

```bash
# カスタムインベントリファイル
export INVENTORY_FILE="inventory/custom_hosts.yml"
python3 generate_inventory.py

# テンプレート作成
export CREATE_TEMPLATE="true"
python3 generate_inventory.py

# 詳細ログ
export LOG_LEVEL="DEBUG"
python3 generate_inventory.py
```

## 🏗️ ロール説明

### system
- システムパッケージの更新・インストール
- 基本的な開発ツールのインストール
- タイムゾーン設定

### apache
- Apache HTTP Serverのインストール・設定
- WordPress用の仮想ホスト設定（HTTPのみ）
- セキュリティヘッダーの設定
- CloudFront対応（HTTPSはCloudFrontで処理）

### php
- PHP 8.4とモジュールのインストール
- PHP-FPMの設定と有効化
- PHP設定の最適化
- OPcache設定
- セキュリティ設定

### wordpress
- WordPressのダウンロード・展開
- wp-config.phpの設定
- ファイル権限の設定
- セキュリティ強化

### security
- fail2banの設定
- ファイアウォール設定
- SELinux設定
- SSHセキュリティ強化
- セキュリティヘッダー設定

### database
- MariaDBクライアントのインストール
- RDS接続設定（adminユーザー）
- データベース接続テスト
- バックアップ設定

### monitoring
- 監視ツールのインストール
- ログローテーション設定
- 自動監視スクリプト
- アラート設定

### ssh
- SSH設定の最適化
- 鍵認証設定
- セキュリティ強化
- 接続制限設定

## 🏗️ 環境設定

### 本番環境 (production.yml)
- デバッグ無効
- セキュリティ強化
- 監視有効
- ログ保持期間: 30日

### 開発環境 (development.yml)
- デバッグ有効
- セキュリティ緩和
- 監視無効
- ログ保持期間: 7日

## 🔧 設定ファイル

### ansible.cfg
- パフォーマンス最適化設定
- セキュリティ強化設定
- ログ設定
- SSH接続設定

### group_vars/
- 環境別変数管理
- セキュリティ設定
- 監視設定
- データベース設定

## 🔍 トラブルシューティング

### 接続エラー
```bash
# SSH鍵の確認
ls -la ~/.ssh/

# 接続テスト
ansible wordpress -m ping

# 詳細接続テスト
ansible wordpress -m setup -a "filter=ansible_default_ipv4"
```

### 構文エラー
```bash
# 構文チェック
ansible-playbook --syntax-check playbooks/wordpress_setup.yml

# ドライラン
ansible-playbook --check --diff playbooks/wordpress_setup.yml
```

### 権限エラー
```bash
# 実行権限の確認
chmod +x run_wordpress_setup.sh
chmod +x lib/common.sh

# SSH鍵の権限確認
chmod 600 ~/.ssh/id_rsa
```

### ログレベルの変更
```bash
export LOG_LEVEL="DEBUG"
./run_wordpress_setup.sh
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
- YAML形式の検証
- 必須項目の確認
- デフォルト値の提供

### 6. セキュリティ
- SSH鍵の適切な管理
- 最小権限の原則
- セキュリティヘッダーの設定
- ファイアウォール設定

### 7. パフォーマンス
- 並列実行の最適化
- キャッシュ機能の活用
- 接続プールの設定

## 🔄 CI/CD

GitHub Actionsワークフローが設定されており、以下の機能を提供します：

- 自動テスト
- 構文チェック
- 環境別デプロイ
- デプロイメント通知
- セキュリティスキャン

## 📋 移行ガイド

### UserDataからAnsibleへの移行
1. UserDataを最小限に縮小
2. Ansibleロールで詳細設定
3. 段階的実行でテスト
4. 本番環境への適用

### メリット
- 宣言的設定
- 冪等性
- モジュール化
- 環境別管理
- 自動化
- セキュリティ強化
- 監視機能

---

*このドキュメントは随時更新されます。最新版を確認してから作業を開始してください。* 