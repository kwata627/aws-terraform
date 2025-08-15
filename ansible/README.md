# Ansible設定管理

このディレクトリには、WordPress環境の設定管理に使用するAnsibleの設定ファイルとプレイブックが含まれています。

## 🚀 新機能: Ansible単独実行（Terraform連携）

このプロジェクトでは、**Ansible単独実行時でもTerraformで設定された値を使用できる**機能を追加しました。

### ✅ 主な改善点

1. **変数統一**: `domain_name`と`wordpress_domain`を統一
2. **ハードコード削除**: プロジェクト固有の値を汎用的なデフォルト値に変更
3. **Terraform連携**: Terraform出力から自動的に変数を取得
4. **単独実行対応**: Ansible単独実行時の利便性向上

### 🔧 使用方法

#### 1. Ansible単独実行スクリプト

```bash
# WordPress環境構築
./ansible/run_ansible_standalone.sh wordpress-setup

# Terraform変数の読み込みのみ
./ansible/run_ansible_standalone.sh load-vars

# SSL証明書設定
./ansible/run_ansible_standalone.sh ssl-setup

# WordPress設定更新
./ansible/run_ansible_standalone.sh update-config
```

#### 2. オプション付き実行

```bash
# 詳細ログ付きで実行
./ansible/run_ansible_standalone.sh -v wordpress-setup

# ドライラン（実際の変更は行わない）
./ansible/run_ansible_standalone.sh --check wordpress-setup

# 特定のタグのみ実行
./ansible/run_ansible_standalone.sh -t "apache,php" wordpress-setup

# 追加変数を指定
./ansible/run_ansible_standalone.sh -e "wordpress_domain=example.com" wordpress-setup
```

#### 3. 従来の方法（Terraform経由）

```bash
# Terraform経由での実行（従来通り）
terraform apply
```

### 🔄 変数の優先順位

Ansible変数は以下の優先順位で設定されます：

1. **環境変数** (最高優先度)
   - `WORDPRESS_DOMAIN`
   - `WORDPRESS_DB_HOST`
   - `WORDPRESS_DB_PASSWORD`
   - `SSH_PRIVATE_KEY_PATH`

2. **Terraform出力** (自動取得)
   - `domain_name`
   - `rds_endpoint`
   - `s3_bucket_name`
   - `project_name`

3. **デフォルト値** (最低優先度)
   - `example.com`
   - `localhost`
   - `password`

### 📁 ファイル構成

```
ansible/
├── playbooks/
│   ├── wordpress_setup.yml          # WordPress環境構築（Terraform連携版）
│   ├── load_terraform_vars.yml      # Terraform変数読み込み
│   ├── lets_encrypt_setup.yml       # SSL証明書設定
│   └── update_wordpress_config.yml  # WordPress設定更新
├── roles/
│   ├── wordpress/                   # WordPress設定ロール
│   ├── apache/                      # Apache設定ロール
│   ├── php/                         # PHP設定ロール
│   └── ...
├── scripts/
│   ├── load_terraform_vars.py       # Terraform変数読み込みスクリプト
│   └── ...
├── group_vars/
│   ├── wordpress.yml                # WordPress用変数
│   └── all/
│       └── terraform_vars.yml       # Terraform出力から生成される変数
├── generate_inventory.py            # インベントリ生成スクリプト
├── run_ansible_standalone.sh        # Ansible単独実行スクリプト
└── ansible.cfg                      # Ansible設定ファイル
```

### 🔧 設定ファイル

#### ansible.cfg
```ini
[defaults]
inventory = inventory/
host_key_checking = False
private_key_file = ~/.ssh/ssh_key
remote_user = ec2-user
timeout = 30
gathering = smart
fact_caching = memory
```

#### group_vars/wordpress.yml
```yaml
# WordPressサーバー用変数
wordpress_domain: "{{ lookup('env', 'WORDPRESS_DOMAIN') | default(lookup('env', 'DOMAIN_NAME') | default('example.com')) }}"
wordpress_db_host: "{{ rds_endpoint | default(lookup('env', 'WORDPRESS_DB_HOST') | default('localhost')) }}"
```

### 🚀 実行例

#### 1. 基本的なWordPress環境構築
```bash
cd ansible
./run_ansible_standalone.sh wordpress-setup
```

#### 2. 特定のロールのみ実行
```bash
./run_ansible_standalone.sh -t "apache,php" wordpress-setup
```

#### 3. ドライランで確認
```bash
./run_ansible_standalone.sh --check --diff wordpress-setup
```

#### 4. カスタムドメインで実行
```bash
./run_ansible_standalone.sh -e "wordpress_domain=my-domain.com" wordpress-setup
```

### 🔍 トラブルシューティング

#### Terraform stateファイルが見つからない場合
```bash
# 警告が表示されますが、デフォルト値で実行されます
./run_ansible_standalone.sh wordpress-setup
```

#### インベントリ生成に失敗した場合
```bash
# テンプレートインベントリが自動的に作成されます
# 環境変数で接続情報を指定してください
export WORDPRESS_PUBLIC_IP="your-ec2-ip"
export SSH_PRIVATE_KEY_FILE="~/.ssh/your-key"
./run_ansible_standalone.sh wordpress-setup
```

#### 権限エラーが発生した場合
```bash
# スクリプトに実行権限を付与
chmod +x run_ansible_standalone.sh
chmod +x scripts/load_terraform_vars.py
```

### 📝 ログファイル

実行ログは以下のファイルに保存されます：
- `ansible_standalone_YYYYMMDD_HHMMSS.log`

### 🔒 セキュリティ

- SSH鍵は`~/.ssh/ssh_key`をデフォルトとして使用
- パスワードは環境変数で管理
- 機密情報はログに出力されません

### 📚 関連ドキュメント

- [WordPress自動デプロイメント手順書](../docs/WordPress自動デプロイメント手順書_統合版.md)
- [WordPress運用手順書](../docs/WordPress運用手順書_統合版.md)
- [検証環境運用ガイド](../docs/検証環境運用ガイド_統合版.md) 