# WordPress Ansible環境

## 概要

このディレクトリには、WordPress環境のAnsible設定が含まれています。UserDataからAnsibleへの移行により、より柔軟で保守性の高いインフラ管理を実現しています。

## ディレクトリ構成

```
ansible/
├── roles/                    # Ansibleロール
│   ├── system/              # システムパッケージ管理
│   ├── apache/              # Apache Webサーバー
│   ├── php/                 # PHP設定
│   ├── wordpress/           # WordPress設定
│   ├── security/            # セキュリティ設定
│   ├── database/            # データベース接続
│   ├── monitoring/          # 監視・ログ設定
│   └── ssh/                 # SSH設定
├── playbooks/               # プレイブック
│   ├── wordpress_setup.yml      # メイン設定
│   ├── step_by_step_setup.yml   # 段階的設定
│   └── configure_ssh.yml        # SSH設定
├── group_vars/              # グループ変数
│   ├── all.yml              # 全環境共通
│   ├── wordpress.yml        # WordPress用
│   └── nat_instance.yml     # NATインスタンス用
├── environments/             # 環境別設定
│   ├── production.yml       # 本番環境
│   └── development.yml      # 開発環境
├── scripts/                 # 実行スクリプト
│   ├── deploy.sh            # デプロイメント
│   └── test_environment.sh  # 環境テスト
└── inventory/               # インベントリ
    └── hosts.yml            # ホスト定義
```

## 使用方法

### 1. 基本的な実行

```bash
# インベントリの更新
cd ansible
python3 generate_inventory.py

# 全環境構築
ansible-playbook playbooks/wordpress_setup.yml

# 段階的実行
ansible-playbook playbooks/step_by_step_setup.yml --tags step1
ansible-playbook playbooks/step_by_step_setup.yml --tags step2
# ...
```

### 2. 環境別デプロイ

```bash
# 本番環境
./scripts/deploy.sh production

# 開発環境
./scripts/deploy.sh development

# 詳細出力付き
./scripts/deploy.sh production playbooks/wordpress_setup.yml true
```

### 3. 環境テスト

```bash
# 環境テストの実行
./scripts/test_environment.sh
```

## ロール説明

### system
- システムパッケージの更新・インストール
- 基本的な開発ツールのインストール

### apache
- Apache HTTP Serverのインストール・設定
- WordPress用の仮想ホスト設定
- セキュリティヘッダーの設定

### php
- PHPとモジュールのインストール
- PHP設定の最適化
- OPcache設定

### wordpress
- WordPressのダウンロード・展開
- wp-config.phpの設定
- ファイル権限の設定

### security
- fail2banの設定
- ファイアウォール設定
- SELinux設定
- SSHセキュリティ強化

### database
- MySQLクライアントのインストール
- データベース接続設定
- 接続テスト

### monitoring
- 監視ツールのインストール
- ログローテーション設定
- 自動監視スクリプト

## 環境変数

### 本番環境 (production.yml)
- デバッグ無効
- セキュリティ強化
- 監視有効

### 開発環境 (development.yml)
- デバッグ有効
- セキュリティ緩和
- 監視無効

## CI/CD

GitHub Actionsワークフローが設定されており、以下の機能を提供します：

- 自動テスト
- 構文チェック
- 環境別デプロイ
- デプロイメント通知

## トラブルシューティング

### 接続エラー
```bash
# SSH鍵の確認
ls -la ~/.ssh/

# 接続テスト
ansible wordpress -m ping
```

### 構文エラー
```bash
# 構文チェック
ansible-playbook --syntax-check playbooks/wordpress_setup.yml
```

### ロール依存関係
各ロールの依存関係は `roles/*/meta/main.yml` で定義されています。

## 移行ガイド

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