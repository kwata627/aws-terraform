# Ansible WordPress環境構築

## 概要

このディレクトリには、WordPress環境の自動構築を行うAnsible設定が含まれています。Terraformで構築されたAWSインフラに対して、WordPressのインストールと設定を自動化します。

## 🚀 新機能: terraform.tfvars直接読み込み

このプロジェクトでは、**terraform.tfvarsを直接読み込む機能**を追加し、Ansible単体実行を可能にしました。

### ✅ 新機能の特徴

#### 1. **Ansible単体実行モード**
- Terraform出力が取得できない環境でも実行可能
- `terraform.tfvars`から直接設定値を読み込み
- `deployment_config.json`との統合設定

#### 2. **設定値の優先順位**
```
1. 環境変数（最高優先度）
2. Terraform出力（動的な値）
3. deployment_config.json
4. terraform.tfvars（ベース設定）
```

#### 3. **実行モード**
- **通常モード**: Terraform出力 + 設定ファイル
- **単体実行モード**: 設定ファイルのみ（terraform.tfvars直接読み込み）

## 使用方法

### 1. 通常の実行（Terraform連携）

```bash
# 基本的な実行
./run_wordpress_setup.sh

# 環境指定
./run_wordpress_setup.sh --environment production

# ドライラン
./run_wordpress_setup.sh --dry-run

# 段階的実行
./run_wordpress_setup.sh --step-by-step
```

### 2. Ansible単体実行（terraform.tfvars直接読み込み）

```bash
# 単体実行スクリプトを使用
./run_standalone.sh

# 環境指定
./run_standalone.sh --environment production

# ドライラン
./run_standalone.sh --dry-run

# 段階的実行
./run_standalone.sh --step-by-step
```

### 3. 環境変数での実行

```bash
# 単体実行モード
export STANDALONE_MODE=true
./run_wordpress_setup.sh

# 設定ファイルパス指定
export TERRAFORM_TFVARS="../terraform.tfvars"
export DEPLOYMENT_CONFIG="../deployment_config.json"
./run_standalone.sh
```

## 設定ファイル

### 1. terraform.tfvars

```hcl
# プロジェクト設定
project = "wp-shamo"
environment = "production"

# ドメイン設定
domain_name = "shamolife.com"

# EC2設定
ec2_name = "wp-shamo-ec2"
instance_type = "t2.micro"

# RDS設定
rds_identifier = "wp-shamo-rds"
db_password = "your-secure-password-here"

# SSL設定
enable_ssl_setup = true
enable_lets_encrypt = true
lets_encrypt_email = "your-email@example.com"
```

### 2. deployment_config.json

```json
{
    "production": {
        "ec2_instance_id": "i-1234567890abcdef0",
        "rds_identifier": "wp-shamo-rds",
        "wordpress_url": "https://shamolife.com",
        "db_password": "your-secure-password"
    }
}
```

## ディレクトリ構造

```
ansible/
├── 📁 roles/                    # Ansibleロール
│   ├── wordpress/              # WordPress設定
│   ├── apache/                 # Apache設定
│   ├── php/                    # PHP設定
│   ├── database/               # データベース設定
│   ├── security/               # セキュリティ設定
│   ├── monitoring/             # 監視設定
│   └── system/                 # システム設定
├── 📁 playbooks/               # プレイブック
│   ├── wordpress_setup.yml     # メイン設定
│   ├── step_by_step_setup.yml  # 段階的設定
│   └── wordpress_debug.yml     # デバッグ用
├── 📁 group_vars/              # グループ変数
│   └── all/
│       └── terraform_vars.yml  # Terraform変数
├── 📁 inventory/               # インベントリ
│   └── hosts.yml               # 動的生成
├── 📁 environments/            # 環境別設定
│   ├── production.yml
│   └── development.yml
├── 📁 scripts/                 # スクリプト
│   ├── load_terraform_vars.py  # 変数読み込み
│   └── test_environment.sh     # 環境テスト
├── generate_inventory.py       # インベントリ生成
├── run_wordpress_setup.sh      # 通常実行スクリプト
├── run_standalone.sh           # 単体実行スクリプト
└── README.md                   # このファイル
```

## 実行フロー

### 通常モード（Terraform連携）

```
1. Terraform出力の取得
2. terraform.tfvarsの読み込み
3. deployment_config.jsonの読み込み
4. 設定値の統合
5. インベントリの生成
6. Ansible変数の生成
7. プレイブックの実行
```

### 単体実行モード（terraform.tfvars直接読み込み）

```
1. terraform.tfvarsの直接読み込み
2. deployment_config.jsonの読み込み
3. 設定値の統合
4. インベントリの生成
5. Ansible変数の生成
6. プレイブックの実行
```

## 環境変数

### 基本設定

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `ENVIRONMENT` | 環境名 | `production` |
| `PLAYBOOK` | プレイブックファイル | `playbooks/wordpress_setup.yml` |
| `DRY_RUN` | ドライラン実行 | `false` |
| `VERBOSE` | 詳細出力 | `false` |
| `LOG_LEVEL` | ログレベル | `INFO` |

### 実行モード設定

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `STANDALONE_MODE` | 単体実行モード | `false` |
| `TERRAFORM_DIR` | Terraformディレクトリ | `../` |
| `TERRAFORM_TFVARS` | terraform.tfvarsパス | `../terraform.tfvars` |
| `DEPLOYMENT_CONFIG` | deployment_config.jsonパス | `../deployment_config.json` |

### データベース設定

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `WORDPRESS_DB_PASSWORD` | データベースパスワード | - |
| `WORDPRESS_DB_USER` | データベースユーザー | `wordpress` |
| `WORDPRESS_DB_NAME` | データベース名 | `wordpress` |

### SSH設定

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `SSH_PRIVATE_KEY_FILE` | SSH秘密鍵ファイル | `~/.ssh/ssh_key` |
| `SSH_USER` | SSHユーザー | `ec2-user` |

## トラブルシューティング

### よくある問題

#### 1. terraform.tfvarsが見つからない

```bash
# エラー
Error: terraform.tfvarsファイルが見つかりません

# 解決方法
# terraform.tfvarsファイルが正しいパスにあるか確認
ls -la ../terraform.tfvars

# 環境変数でパスを指定
export TERRAFORM_TFVARS="/path/to/terraform.tfvars"
```

#### 2. IPアドレスが設定されていない

```bash
# エラー
Warning: WordPress EC2のIPアドレスが設定されていません

# 解決方法
# deployment_config.jsonにIPアドレスを設定
{
    "production": {
        "ec2_instance_id": "i-1234567890abcdef0",
        "wordpress_public_ip": "203.0.113.10"
    }
}
```

#### 3. 接続テストに失敗

```bash
# エラー
Warning: 接続テストで一部のホストに接続できませんでした

# 解決方法
# SSH鍵とIPアドレスを確認
ssh -i ~/.ssh/ssh_key ec2-user@203.0.113.10

# セキュリティグループの設定を確認
```

### デバッグ方法

#### 1. 詳細ログの有効化

```bash
export VERBOSE=true
export LOG_LEVEL=DEBUG
./run_standalone.sh
```

#### 2. ドライラン実行

```bash
./run_standalone.sh --dry-run
```

#### 3. 段階的実行

```bash
./run_standalone.sh --step-by-step
```

## セキュリティ

### 1. パスワード管理

- データベースパスワードは環境変数で管理
- 設定ファイルには平文で保存しない
- 強力なパスワードを使用

### 2. SSH鍵管理

- SSH秘密鍵は安全に管理
- 適切な権限設定（600）
- 定期的な鍵のローテーション

### 3. 設定ファイル

- 機密情報を含むファイルはGitにコミットしない
- `.gitignore`で適切に除外
- 環境別の設定ファイルを使用

## ベストプラクティス

### 1. 設定管理

- 環境別の設定ファイルを使用
- 設定値の優先順位を理解
- 機密情報は環境変数で管理

### 2. 実行方法

- 本番環境では必ずドライランを先に実行
- 段階的実行で問題を特定
- ログを確認してエラーを把握

### 3. メンテナンス

- 定期的な設定の見直し
- セキュリティアップデートの適用
- バックアップの確認

## 次のステップ

1. **環境の準備**: terraform.tfvarsとdeployment_config.jsonの設定
2. **単体実行テスト**: `./run_standalone.sh --dry-run`
3. **本番実行**: `./run_standalone.sh`
4. **環境テスト**: 動作確認とセキュリティチェック

## サポート

問題や質問がある場合は、以下を確認してください：

1. ログファイルの確認
2. 設定ファイルの構文チェック
3. 接続テストの実行
4. ドキュメントの参照 