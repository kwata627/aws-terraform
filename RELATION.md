# ファイル依存関係マップ (RELATION.md)

## 📋 **概要**

このドキュメントは、WordPress AWS Infrastructure プロジェクトにおける各ファイル間の依存関係を網羅的にマッピングしたものです。GitHub Actionsワークフローの統合修正時に影響を受ける可能性のあるファイルとその関係性を明確化します。

## 🏗️ **Terraformファイル群の依存関係**

### **メインファイル階層**

```
main.tf
├── variables.tf (変数定義)
├── locals.tf (ローカル変数)
├── outputs.tf (出力定義)
├── provider.tf (プロバイダー設定)
└── terraform.tfvars (変数値)
```

### **モジュール依存関係**

#### **1. メインモジュール (main.tf)**
```
main.tf
├── ./modules/ssh
├── ./modules/nat-instance
├── ./modules/network
├── ./modules/security
├── ./modules/ec2
├── ./modules/rds
├── ./modules/s3
├── ./modules/route53
├── ./modules/acm (コメントアウト)
└── ./modules/cloudfront (コメントアウト)
```

#### **2. 出力依存関係 (outputs.tf)**
```
outputs.tf
├── module.ec2 (public_ip, public_dns, instance_id, validation_private_ip, validation_instance_id, availability_zone)
├── module.ssh (private_key_pem)
├── module.rds (db_endpoint, db_port)
├── module.s3 (bucket_name, bucket_arn, bucket_domain_name, access_logs_bucket_name, encryption_enabled, public_access_blocked, versioning_enabled)
├── module.route53 (domain_expiration_date, domain_registration_status, name_servers, wordpress_dns_record)
├── module.acm (certificate_arn, certificate_domain_name)
├── module.cloudfront (distribution_domain_name)
├── module.nat_instance (nat_instance_id)
└── module.network (vpc_id, public_subnet_ids, private_subnet_ids)
```

#### **3. 各モジュールの内部構造**
```
modules/[module_name]/
├── main.tf (メインリソース)
├── variables.tf (変数定義)
├── outputs.tf (出力定義)
├── data.tf (データソース)
├── locals.tf (ローカル変数)
└── [module-specific].tf (モジュール固有ファイル)
```

## 🎭 **Ansibleファイル群の依存関係**

### **プレイブック階層**

#### **1. メインプレイブック (wordpress_setup.yml)**
```
ansible/playbooks/wordpress_setup.yml
├── ansible/scripts/load_terraform_vars.py (Terraform変数読み込み)
├── ansible/inventory/hosts.yml (インベントリ)
├── ansible/group_vars/all/terraform_vars.yml (Terraform変数)
└── ansible/roles/
    ├── system
    ├── database
    ├── apache
    ├── php
    ├── security
    ├── wordpress
    └── ssh
```

#### **2. ロール依存関係**
```
ansible/roles/[role_name]/
├── tasks/main.yml (メインタスク)
├── defaults/main.yml (デフォルト値)
├── handlers/main.yml (ハンドラー)
├── meta/main.yml (メタ情報)
├── templates/ (テンプレートファイル)
└── files/ (静的ファイル)
```

#### **3. インベントリ生成**
```
ansible/generate_inventory.py
├── ../terraform.tfstate (Terraform状態)
├── ../terraform.tfvars (Terraform変数)
└── ansible/inventory/hosts.yml (生成先)
```

#### **4. 変数読み込み**
```
ansible/scripts/load_terraform_vars.py
├── ../terraform.tfstate (Terraform状態)
└── ansible/group_vars/all/terraform_vars.yml (生成先)
```

## 🔧 **スクリプトファイル群の依存関係**

### **デプロイメントスクリプト**
```
scripts/deployment/
├── auto_deployment.sh
│   ├── deployment_config.json
│   ├── ansible/generate_inventory.py
│   └── ansible/playbooks/wordpress_setup.yml
├── deploy_to_production.sh
│   ├── deployment_config.json
│   ├── scripts/deployment/prepare_validation.sh
│   └── ansible/playbooks/wordpress_setup.yml
├── prepare_validation.sh
│   ├── deployment_config.json
│   └── terraform.tfstate
└── test_environment.sh
    ├── deployment_config.json
    └── ansible/inventory/hosts.yml
```

### **セットアップスクリプト**
```
scripts/setup/
├── ansible_auto_setup.sh
│   ├── terraform.tfstate
│   ├── ansible/generate_inventory.py
│   └── ansible/playbooks/wordpress_setup.yml
├── setup_deployment.sh
│   ├── scripts/templates/deployment_config.template.json
│   └── deployment_config.json
├── ssh_key_setup.sh
│   ├── terraform.tfstate
│   └── ~/.ssh/ (SSH鍵配置)
└── terraform_config.sh
    ├── terraform.tfvars.example
    └── terraform.tfvars
```

### **検証・メンテナンススクリプト**
```
scripts/
├── validate-ssl-setup.sh
│   ├── terraform.tfstate
│   └── terraform_output.json
├── test_environment.sh
│   ├── deployment_config.json
│   └── ansible/inventory/hosts.yml
├── test_monitoring.sh
│   ├── deployment_config.json
│   └── ansible/inventory/hosts.yml
└── maintenance/rollback.sh
    ├── deployment_config.json
    └── terraform.tfstate
```

## 🚀 **GitHub Actionsワークフローの依存関係**

### **ワークフロー分類と依存ファイル**

#### **1. WordPress環境構築系**
```
.github/workflows/wordpress-setup.yml
├── ansible/playbooks/wordpress_setup.yml
├── ansible/scripts/load_terraform_vars.py
├── ansible/inventory/hosts.yml
├── scripts/validate-ssl-setup.sh
└── terraform.tfstate

.github/workflows/ansible-wordpress-setup.yml
├── ansible/playbooks/wordpress_setup.yml
├── ansible/generate_inventory.py
├── ansible/inventory/hosts.yml
├── deployment_config.json
└── terraform.tfstate

.github/workflows/wordpress-deploy.yml
├── ansible/playbooks/wordpress_setup.yml
├── ansible/generate_inventory.py
├── ansible/inventory/hosts.yml
└── ansible/scripts/deploy.sh
```

#### **2. デプロイメント系**
```
.github/workflows/wordpress-deployment.yml
├── deployment_config.json
├── scripts/deployment/auto_deployment.sh
├── scripts/deployment/prepare_validation.sh
├── scripts/deployment/deploy_to_production.sh
└── terraform.tfstate

.github/workflows/deploy-to-production.yml
├── deployment_config.json
├── scripts/deployment/deploy_to_production.sh
├── scripts/deployment/prepare_validation.sh
└── terraform.tfstate

.github/workflows/auto-deployment.yml
├── deployment_config.json
├── ansible/generate_inventory.py
├── ansible/playbooks/wordpress_setup.yml
└── terraform.tfstate

.github/workflows/prepare-validation.yml
├── deployment_config.json
├── scripts/deployment/prepare_validation.sh
└── terraform.tfstate
```

#### **3. 設定管理系**
```
.github/workflows/terraform-config.yml
├── terraform.tfvars
├── deployment_config.json
├── variables.tf
├── main.tf
└── scripts/setup/terraform_config.sh

.github/workflows/setup-deployment.yml
├── terraform.tfvars
├── deployment_config.json
├── scripts/templates/deployment_config.template.json
└── scripts/setup/setup_deployment.sh
```

#### **4. 監視・検証系**
```
.github/workflows/ssl-validation.yml
├── scripts/validate-ssl-setup.sh
├── terraform.tfstate
└── terraform_output.json

.github/workflows/certificate-monitoring.yml
├── terraform.tfstate
├── terraform_output.json
└── certificate-renewal-check.log

.github/workflows/ansible-environment-test.yml
├── ansible/generate_inventory.py
├── ansible/inventory/hosts.yml
├── deployment_config.json
└── terraform.tfstate

.github/workflows/ansible-monitoring-test.yml
├── ansible/generate_inventory.py
├── ansible/inventory/hosts.yml
├── deployment_config.json
└── terraform.tfstate
```

#### **5. 運用管理系**
```
.github/workflows/rollback.yml
├── deployment_config.json
├── scripts/maintenance/rollback.sh
└── terraform.tfstate

.github/workflows/update-ssh-cidr.yml
├── terraform.tfvars
├── variables.tf
└── main.tf
```

## 🔄 **環境変数とシークレットの依存関係**

### **GitHub Secrets**
```
GitHub Secrets
├── AWS_ACCESS_KEY_ID (全ワークフロー)
├── AWS_SECRET_ACCESS_KEY (全ワークフロー)
├── AWS_REGION (全ワークフロー)
├── SSH_PRIVATE_KEY (Ansible系ワークフロー)
├── SLACK_WEBHOOK_URL (通知系ワークフロー)
├── APPROVAL_SECRET (承認系ワークフロー)
└── APPROVERS (承認系ワークフロー)
```

### **環境変数ファイル**
```
ansible/example.env
├── ansible/load_env.sh
└── ansible/playbooks/wordpress_setup.yml

ansible/env.example.current
├── ansible/load_env.sh
└── ansible/playbooks/wordpress_setup.yml
```

## 📁 **設定ファイルの依存関係**

### **デプロイメント設定**
```
deployment_config.json
├── scripts/deployment/auto_deployment.sh
├── scripts/deployment/deploy_to_production.sh
├── scripts/deployment/prepare_validation.sh
├── scripts/deployment/test_environment.sh
├── scripts/maintenance/rollback.sh
└── 全デプロイメント系ワークフロー

deployment_config.example.json
├── scripts/setup/setup_deployment.sh
└── .github/workflows/setup-deployment.yml
```

### **Terraform設定**
```
terraform.tfvars
├── terraform plan/apply
├── ansible/generate_inventory.py
├── ansible/scripts/load_terraform_vars.py
└── 全Terraform系ワークフロー

terraform.tfvars.example
├── scripts/setup/terraform_config.sh
└── .github/workflows/terraform-config.yml
```

### **Ansible設定**
```
ansible/ansible.cfg
├── 全Ansibleプレイブック
└── 全Ansible系ワークフロー

ansible/inventory/hosts.yml
├── 全Ansibleプレイブック
├── ansible/generate_inventory.py
└── 全Ansible系ワークフロー
```

## ⚠️ **統合修正時の影響範囲**

### **高影響度ファイル (直接修正が必要)**
1. **ワークフロー実行に必須**
   - `ansible/generate_inventory.py`
   - `ansible/scripts/load_terraform_vars.py`
   - `scripts/validate-ssl-setup.sh`
   - `deployment_config.json`

2. **設定ファイル**
   - `ansible/ansible.cfg`
   - `ansible/playbooks/wordpress_setup.yml`
   - `terraform.tfvars`

3. **スクリプトファイル**
   - `scripts/deployment/auto_deployment.sh`
   - `scripts/deployment/deploy_to_production.sh`
   - `scripts/deployment/prepare_validation.sh`

### **中影響度ファイル (間接的に影響)**
1. **モジュール出力**
   - `modules/*/outputs.tf`
   - `modules/*/variables.tf`

2. **ロールファイル**
   - `ansible/roles/*/tasks/main.yml`
   - `ansible/roles/*/defaults/main.yml`

3. **テンプレートファイル**
   - `ansible/templates/`
   - `modules/*/userdata.tpl`

### **低影響度ファイル (監視のみ)**
1. **ドキュメント**
   - `README.md`
   - `docs/`

2. **バックアップファイル**
   - `backups/`

## 🛡️ **統合修正時の注意点**

### **1. ファイルパスの変更**
- ワークフロー統合時に相対パス参照の修正が必要
- 特に `ansible/` ディレクトリ内のファイル参照

### **2. 環境変数の統一**
- 複数ワークフローで異なる環境変数名を使用
- 統一された環境変数名への変更が必要

### **3. 実行順序の調整**
- 現在は独立して実行可能
- 統合後は依存関係の明確化が必要

### **4. エラーハンドリングの統一**
- 各ワークフローで異なるエラーハンドリング方式
- 統一されたエラーハンドリングへの変更が必要

## 📊 **依存関係マトリックス**

### **ファイル間の依存度**

| ファイル | 依存先 | 依存度 | 影響範囲 |
|---------|--------|--------|----------|
| `main.tf` | `variables.tf`, `locals.tf` | 高 | 全モジュール |
| `outputs.tf` | 全モジュール | 高 | 全ワークフロー |
| `ansible/playbooks/wordpress_setup.yml` | `ansible/roles/`, `ansible/inventory/` | 高 | Ansible系ワークフロー |
| `deployment_config.json` | なし | 中 | デプロイメント系ワークフロー |
| `terraform.tfvars` | なし | 中 | Terraform系ワークフロー |
| `ansible/generate_inventory.py` | `terraform.tfstate` | 高 | 全Ansible系ワークフロー |
| `scripts/validate-ssl-setup.sh` | `terraform.tfstate` | 中 | SSL系ワークフロー |

### **ワークフロー間の依存度**

| ワークフロー | 依存先ワークフロー | 依存度 | 統合優先度 |
|-------------|------------------|--------|-----------|
| `wordpress-setup.yml` | なし | 低 | 高 |
| `ansible-wordpress-setup.yml` | なし | 低 | 高 |
| `wordpress-deploy.yml` | なし | 低 | 高 |
| `wordpress-deployment.yml` | `prepare-validation.yml` | 中 | 中 |
| `deploy-to-production.yml` | `prepare-validation.yml` | 中 | 中 |
| `auto-deployment.yml` | なし | 低 | 中 |
| `prepare-validation.yml` | なし | 低 | 中 |
| `terraform-config.yml` | なし | 低 | 低 |
| `ssl-validation.yml` | なし | 低 | 低 |
| `certificate-monitoring.yml` | なし | 低 | 低 |

## 🎯 **統合修正の推奨順序**

### **Phase 1: WordPress環境構築系の統合**
1. `wordpress-setup.yml`
2. `ansible-wordpress-setup.yml`
3. `wordpress-deploy.yml`
→ 統合後: `wordpress-environment.yml`

### **Phase 2: デプロイメント系の統合**
1. `wordpress-deployment.yml`
2. `deploy-to-production.yml`
3. `auto-deployment.yml`
4. `prepare-validation.yml`
→ 統合後: `deployment-pipeline.yml`

### **Phase 3: 監視・検証系の統合**
1. `ssl-validation.yml`
2. `certificate-monitoring.yml`
3. `ansible-environment-test.yml`
4. `ansible-monitoring-test.yml`
→ 統合後: `monitoring-validation.yml`

### **Phase 4: 運用管理系の統合**
1. `rollback.yml`
2. `update-ssh-cidr.yml`
→ 統合後: `operations-management.yml`

### **Phase 5: 設定管理系の統合**
1. `terraform-config.yml`
2. `setup-deployment.yml`
→ 統合後: `configuration-management.yml`

## 📝 **更新履歴**

- **2025-08-16**: 初版作成
- 依存関係マップの網羅的調査完了
- GitHub Actionsワークフロー統合計画策定

---

**注意**: このドキュメントは、GitHub Actionsワークフローの統合修正作業の事前準備として作成されました。実際の修正作業時には、この依存関係マップを参照して安全に統合を進めてください。
