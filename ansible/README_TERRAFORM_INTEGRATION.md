# Ansible Terraform連携ガイド

## 概要

このプロジェクトでは、AnsibleがTerraformの出力と設定ファイルを自動的に読み取り、適切な値を設定に使用します。これにより、Ansible単独実行時でもTerraformで指定された値を使用できます。

## 機能

### 1. 自動値取得
- **Terraform出力**: `terraform_output.json`から値を自動取得
- **Terraform設定**: `terraform.tfvars`から設定値を自動取得
- **環境変数**: 従来の環境変数による設定もサポート
- **デフォルト値**: 普遍的なデフォルト値（`example.com`、`wp-example`など）

### 2. 優先順位
1. Terraform設定ファイル（`terraform.tfvars`）
2. Terraform出力（`terraform_output.json`）
3. 環境変数
4. デフォルト値

## 使用方法

### 基本的な使用方法

```bash
# 1. Terraformでインフラを構築
terraform apply

# 2. Ansibleインベントリを生成
cd ansible
python3 generate_inventory.py

# 3. Ansibleを実行（Terraformの値が自動的に使用される）
ansible-playbook playbooks/wordpress_setup.yml
```

### 手動で値を指定する場合

```bash
# 環境変数で値を上書き
export WORDPRESS_DOMAIN="my-domain.com"
export WORDPRESS_DB_PASSWORD="my-password"
ansible-playbook playbooks/wordpress_setup.yml
```

## 利用可能な変数

### WordPress設定
- `wordpress_domain`: WordPressドメイン名
- `wordpress_db_host`: データベースホスト
- `wordpress_db_password`: データベースパスワード

### プロジェクト設定
- `project_name`: プロジェクト名
- `wordpress_public_ip`: WordPress EC2のパブリックIP
- `nat_instance_public_ip`: NATインスタンスのパブリックIP

### RDS設定
- `rds_endpoint`: RDSエンドポイント
- `rds_identifier`: RDS識別子

### S3設定
- `s3_bucket_name`: S3バケット名
- `s3_bucket_arn`: S3バケットARN

### Route53設定
- `route53_zone_id`: Route53ホストゾーンID
- `route53_name_servers`: ネームサーバーリスト

## カスタムフィルター

### terraform_output
Terraformの出力ファイルから値を取得

```yaml
# 全データを取得
terraform_data: "{{ terraform_output_file | terraform_output }}"

# 特定のキーの値を取得
wordpress_ip: "{{ terraform_output_file | terraform_output('wordpress_public_ip') }}"

# ネストしたキーの値を取得
rds_endpoint: "{{ terraform_output_file | terraform_output('rds_endpoint.value') }}"
```

### terraform_state
Terraformのstateファイルからリソース情報を取得

```yaml
# 特定のリソース情報を取得
ec2_info: "{{ terraform_state_file | terraform_state('aws_instance', 'wordpress') }}"
```

### load_terraform_config
Terraform設定ファイルを読み取り

```yaml
# terraform.tfvarsを読み取り
terraform_config: "{{ terraform_config_file | load_terraform_config }}"
```

### terraform_value
Terraformデータから指定されたパスの値を取得

```yaml
# パス指定で値を取得
wordpress_ip: "{{ terraform_output | terraform_value('wordpress_public_ip.value') }}"
```

## 設定例

### group_vars/all.yml
```yaml
# Terraform連携設定
terraform_output_file: "{{ playbook_dir }}/../terraform_output.json"
terraform_state_file: "{{ playbook_dir }}/../terraform.tfstate"
terraform_config_file: "{{ playbook_dir }}/../terraform.tfvars"

# Terraformの値を自動取得
terraform_output: "{{ terraform_output_file | terraform_output }}"
terraform_config: "{{ terraform_config_file | load_terraform_config }}"

# WordPress設定（Terraformの値を優先）
wordpress_domain: "{{ terraform_config.domain_name | default(lookup('env', 'WORDPRESS_DOMAIN') | default('example.com')) }}"
wordpress_db_host: "{{ terraform_output | terraform_value('rds_endpoint.value') | default(lookup('env', 'WORDPRESS_DB_HOST') | default('localhost')) }}"
wordpress_db_password: "{{ terraform_config.db_password | default(lookup('env', 'WORDPRESS_DB_PASSWORD') | default('your-secure-password-here')) }}"
```

## トラブルシューティング

### Terraformファイルが見つからない場合
```bash
# エラー: Terraform出力ファイルが見つかりません
# 解決策: terraform applyを実行してからAnsibleを実行
terraform apply
cd ansible
ansible-playbook playbooks/wordpress_setup.yml
```

### 値が正しく取得されない場合
```bash
# デバッグ情報を確認
ansible-playbook playbooks/wordpress_setup.yml -v

# 特定の変数の値を確認
ansible-playbook playbooks/wordpress_setup.yml -e "debug_vars=true"
```

### カスタムフィルターが動作しない場合
```bash
# フィルタープラグインのパスを確認
ansible --version

# フィルタープラグインを手動でテスト
python3 -c "
from ansible.plugins.filter.terraform_filters import FilterModule
f = FilterModule()
print(f.terraform_output('terraform_output.json', 'wordpress_public_ip'))
"
```

## ベストプラクティス

### 1. デフォルト値の設定
- プロジェクト固有の値をデフォルトにしない
- 普遍的な値（`example.com`、`wp-example`）を使用
- 環境変数で上書き可能にする

### 2. エラーハンドリング
- ファイルが存在しない場合の適切な処理
- 値が取得できない場合のフォールバック
- ログ出力によるデバッグ情報の提供

### 3. セキュリティ
- 機密情報は環境変数で管理
- パスワードなどの値は適切に暗号化
- ログに機密情報を出力しない

## 更新履歴

- **v2.0.0**: Terraform連携機能を追加
- **v2.1.0**: カスタムフィルターを追加
- **v2.2.0**: エラーハンドリングを改善
