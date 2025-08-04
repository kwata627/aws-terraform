# EC2 Instance Module

## 概要

このモジュールはAWS EC2インスタンスを作成し、WordPress環境の基盤を提供します。本番環境と検証環境の両方をサポートし、Ansibleとの統合を考慮した設計となっています。

## 特徴

- **本番用と検証用の分離**: 環境別のインスタンス管理
- **柔軟なUserDataテンプレート**: カスタマイズ可能な初期設定
- **セキュリティ強化**: IMDSv2必須、暗号化ボリューム
- **自動スケーリング対応**: CloudWatchアラーム統合
- **詳細なモニタリング**: パフォーマンス監視機能

## 使用方法

### 基本的な使用例

```hcl
module "ec2" {
  source = "./modules/ec2"
  
  project     = "my-project"
  ami_id      = "ami-095af7cb7ddb447ef"
  instance_type = "t2.micro"
  subnet_id   = module.network.public_subnet_id
  security_group_id = module.security.ec2_sg_id
  key_name    = module.ssh.key_name
  ssh_public_key = module.ssh.public_key_openssh
}
```

### 高度な設定例

```hcl
module "ec2" {
  source = "./modules/ec2"
  
  project     = "my-project"
  ami_id      = "ami-095af7cb7ddb447ef"
  instance_type = "t3.micro"
  subnet_id   = module.network.public_subnet_id
  security_group_id = module.security.ec2_sg_id
  key_name    = module.ssh.key_name
  ssh_public_key = module.ssh.public_key_openssh
  
  # 環境設定
  environment = "production"
  
  # ストレージ設定
  root_volume_size = 20
  root_volume_type = "gp3"
  root_volume_encrypted = true
  
  # 検証環境
  enable_validation_ec2 = true
  private_subnet_id = module.network.private_subnet_id
  validation_security_group_id = module.security.validation_sg_id
  
  # モニタリング
  enable_cloudwatch_alarms = true
  enable_detailed_monitoring = true
  
  # カスタムタグ
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Compliance  = "PCI-DSS"
  }
}
```

## 入力変数

### 必須変数

| 変数名 | 型 | 説明 | 例 |
|--------|----|----|-----|
| `project` | `string` | プロジェクト名（リソース名のprefix用） | `"my-project"` |
| `ami_id` | `string` | EC2インスタンス用のAMI ID | `"ami-095af7cb7ddb447ef"` |
| `instance_type` | `string` | EC2インスタンスタイプ | `"t2.micro"` |
| `subnet_id` | `string` | サブネットID | `"subnet-xxxxxxxx"` |
| `security_group_id` | `string` | セキュリティグループID | `"sg-xxxxxxxx"` |
| `key_name` | `string` | SSHキーペア名 | `"my-key-pair"` |
| `ssh_public_key` | `string` | SSH公開鍵の内容 | `"ssh-rsa AAAAB3..."` |

### オプション変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `environment` | `string` | `"production"` | 環境名（dev, staging, production, test） |
| `ec2_name` | `string` | `""` | EC2インスタンスのNameタグ |
| `root_volume_size` | `number` | `8` | ルートボリュームサイズ（GB） |
| `root_volume_type` | `string` | `"gp2"` | ルートボリュームタイプ |
| `root_volume_encrypted` | `bool` | `true` | ルートボリュームの暗号化 |
| `delete_on_termination` | `bool` | `true` | インスタンス終了時のボリューム削除 |
| `associate_public_ip` | `bool` | `true` | パブリックIPの割り当て |
| `enable_detailed_monitoring` | `bool` | `false` | 詳細モニタリングの有効化 |
| `shutdown_behavior` | `string` | `"stop"` | シャットダウン時の動作 |
| `user_data_template_path` | `string` | `"modules/ec2/userdata_minimal.tpl"` | UserDataテンプレートパス |
| `additional_user_data_scripts` | `string` | `""` | 追加のUserDataスクリプト |
| `tags` | `map(string)` | `{}` | 追加のタグ |

### 検証環境変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `enable_validation_ec2` | `bool` | `false` | 検証用EC2インスタンスの作成有無 |
| `validation_instance_type` | `string` | `"t2.micro"` | 検証用インスタンスタイプ |
| `private_subnet_id` | `string` | `""` | 検証用プライベートサブネットID |
| `validation_security_group_id` | `string` | `""` | 検証用セキュリティグループID |
| `validation_ec2_name` | `string` | `""` | 検証用EC2インスタンスのNameタグ |
| `validation_root_volume_size` | `number` | `8` | 検証用ルートボリュームサイズ |
| `validation_user_data_template_path` | `string` | `"modules/ec2/userdata_minimal.tpl"` | 検証用UserDataテンプレートパス |

### モニタリング変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `enable_cloudwatch_alarms` | `bool` | `false` | CloudWatchアラームの有効化 |
| `alarm_actions` | `list(string)` | `[]` | CloudWatchアラームのアクション |

## 出力値

### 本番インスタンス情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `instance_id` | `string` | EC2インスタンスのID |
| `instance_arn` | `string` | EC2インスタンスのARN |
| `instance_state` | `string` | EC2インスタンスの現在の状態 |
| `public_ip` | `string` | パブリックIPアドレス |
| `public_dns` | `string` | パブリックDNS名 |
| `private_ip` | `string` | プライベートIPアドレス |
| `private_dns` | `string` | プライベートDNS名 |

### インスタンス詳細

| 出力名 | 型 | 説明 |
|--------|----|------|
| `instance_type` | `string` | EC2インスタンスタイプ |
| `availability_zone` | `string` | アベイラビリティゾーン |
| `subnet_id` | `string` | サブネットID |
| `vpc_security_group_ids` | `list(string)` | セキュリティグループID |
| `root_block_device` | `object` | ルートボリュームの詳細情報 |

### 検証インスタンス情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `validation_instance_id` | `string` | 検証用EC2インスタンスのID |
| `validation_instance_state` | `string` | 検証用EC2インスタンスの状態 |
| `validation_private_ip` | `string` | 検証用プライベートIP |
| `validation_private_dns` | `string` | 検証用プライベートDNS |
| `validation_instance_type` | `string` | 検証用インスタンスタイプ |
| `validation_subnet_id` | `string` | 検証用サブネットID |

### Elastic IP情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `elastic_ip_id` | `string` | Elastic IPのID |
| `elastic_ip_arn` | `string` | Elastic IPのARN |

### CloudWatchアラーム

| 出力名 | 型 | 説明 |
|--------|----|------|
| `cloudwatch_alarms` | `object` | CloudWatchアラームの情報 |

## UserDataテンプレート

### 利用可能なテンプレート

1. **userdata_minimal.tpl**: 最小限の設定（Ansible移行用）
2. **userdata_enhanced.tpl**: 詳細な設定（セキュリティ強化版）
3. **userdata.tpl**: 従来のWordPress設定

### カスタムテンプレートの作成

```bash
# テンプレートファイルの作成
cat > modules/ec2/custom_userdata.tpl << 'EOF'
#!/bin/bash
# カスタムUserDataスクリプト
echo "Custom UserData executed at $(date)"
# 追加の設定をここに記述
EOF
```

### テンプレート変数

以下の変数がテンプレート内で利用可能です：

- `${ssh_public_key}`: SSH公開鍵
- `${project}`: プロジェクト名
- `${environment}`: 環境名
- `${additional_scripts}`: 追加スクリプト

## セキュリティ考慮事項

### 推奨事項

1. **IMDSv2の使用**: インスタンスメタデータサービスのセキュリティ強化
2. **ボリューム暗号化**: データ保護のため暗号化を有効化
3. **最小権限の原則**: セキュリティグループで必要最小限の通信のみ許可
4. **定期的な更新**: セキュリティパッチの自動適用

### 注意事項

- パブリックIPの使用は必要最小限に制限
- 検証環境はプライベートサブネットに配置
- 適切なタグ付けによるリソース管理

## トラブルシューティング

### よくある問題

#### 1. インスタンスが起動しない

**原因**: UserDataスクリプトのエラー

**解決方法**:
```bash
# ログの確認
ssh ec2-user@<instance-ip> "sudo cat /var/log/user-data.log"

# システムログの確認
ssh ec2-user@<instance-ip> "sudo journalctl -u cloud-init"
```

#### 2. SSH接続ができない

**原因**: SSH設定の不備

**解決方法**:
```bash
# SSH設定の確認
ssh ec2-user@<instance-ip> "ls -la ~/.ssh/"

# SSHサービスの確認
ssh ec2-user@<instance-ip> "sudo systemctl status sshd"
```

#### 3. ボリュームが暗号化されていない

**原因**: 暗号化設定の不備

**解決方法**:
```hcl
# 暗号化を有効化
root_volume_encrypted = true
```

## 更新履歴

- **v1.0.0**: 初回リリース
  - 本番・検証環境の分離
  - 柔軟なUserDataテンプレート
  - セキュリティ強化
  - CloudWatchアラーム統合
  - 詳細なモニタリング機能

## ライセンス

このモジュールは学習目的で作成されており、個人利用を想定しています。 