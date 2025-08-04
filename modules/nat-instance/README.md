# NAT Instance Module

## 概要

このモジュールはAWS EC2インスタンスを使用してNAT（Network Address Translation）インスタンスを作成し、プライベートサブネットからのインターネットアクセスを提供します。NAT Gatewayの代替としてコスト効率的なソリューションです。

## 特徴

- **コスト効率的**: NAT Gatewayよりも低コスト
- **セキュリティ強化**: IMDSv2必須、暗号化ボリューム
- **自動NAT設定**: iptablesによる自動設定
- **高可用性対応**: 複数AZでの冗長化可能
- **詳細なモニタリング**: CloudWatchアラーム統合

## 使用方法

### 基本的な使用例

```hcl
module "nat_instance" {
  source = "./modules/nat-instance"
  
  project     = "my-project"
  ami_id      = "ami-095af7cb7ddb447ef"
  instance_type = "t3.nano"
  subnet_id   = module.network.public_subnet_id
  security_group_id = module.security.nat_sg_id
  key_name    = module.ssh.key_name
  ssh_public_key = module.ssh.public_key_openssh
  ssh_private_key = module.ssh.private_key_pem
}
```

### 高度な設定例

```hcl
module "nat_instance" {
  source = "./modules/nat-instance"
  
  project     = "my-project"
  ami_id      = "ami-095af7cb7ddb447ef"
  instance_type = "t3.micro"
  subnet_id   = module.network.public_subnet_id
  security_group_id = module.security.nat_sg_id
  key_name    = module.ssh.key_name
  ssh_public_key = module.ssh.public_key_openssh
  ssh_private_key = module.ssh.private_key_pem
  
  # 環境設定
  environment = "production"
  vpc_cidr    = "10.0.0.0/16"
  
  # ストレージ設定
  root_volume_size = 20
  root_volume_type = "gp3"
  root_volume_encrypted = true
  
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
| `subnet_id` | `string` | NATインスタンスを配置するパブリックサブネットID | `"subnet-xxxxxxxx"` |
| `security_group_id` | `string` | NATインスタンス用のセキュリティグループID | `"sg-xxxxxxxx"` |
| `ami_id` | `string` | NATインスタンス用AMI ID | `"ami-095af7cb7ddb447ef"` |
| `instance_type` | `string` | NATインスタンスのインスタンスタイプ | `"t3.nano"` |
| `key_name` | `string` | SSHキーペア名 | `"my-key-pair"` |
| `ssh_public_key` | `string` | SSH公開鍵の内容 | `"ssh-rsa AAAAB3..."` |
| `ssh_private_key` | `string` | SSH秘密鍵の内容 | `"-----BEGIN RSA PRIVATE KEY-----"` |

### オプション変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `environment` | `string` | `"production"` | 環境名（dev, staging, production, test） |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | VPCのCIDRブロック（NAT設定用） |
| `root_volume_size` | `number` | `8` | ルートボリュームサイズ（GB） |
| `root_volume_type` | `string` | `"gp2"` | ルートボリュームタイプ |
| `root_volume_encrypted` | `bool` | `true` | ルートボリュームの暗号化 |
| `delete_on_termination` | `bool` | `true` | インスタンス終了時のボリューム削除 |
| `enable_detailed_monitoring` | `bool` | `false` | 詳細モニタリングの有効化 |
| `shutdown_behavior` | `string` | `"stop"` | シャットダウン時の動作 |
| `user_data_template_path` | `string` | `"modules/nat-instance/userdata.tpl"` | UserDataテンプレートパス |
| `additional_user_data_scripts` | `string` | `""` | 追加のUserDataスクリプト |
| `tags` | `map(string)` | `{}` | 追加のタグ |

### 高度な設定変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `enable_cloudwatch_alarms` | `bool` | `false` | CloudWatchアラームの有効化 |
| `alarm_actions` | `list(string)` | `[]` | CloudWatchアラームのアクション |
| `enable_network_interface` | `bool` | `false` | ネットワークインターフェースの有効化 |

## 出力値

### インスタンス情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `nat_instance_id` | `string` | NATインスタンスのID |
| `nat_instance_arn` | `string` | NATインスタンスのARN |
| `nat_instance_state` | `string` | NATインスタンスの現在の状態 |
| `nat_instance_network_interface_id` | `string` | NATインスタンスのネットワークインターフェースID |

### ネットワーク情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `nat_public_ip` | `string` | NATインスタンスのパブリックIPアドレス |
| `nat_public_dns` | `string` | NATインスタンスのパブリックDNS名 |
| `nat_private_ip` | `string` | NATインスタンスのプライベートIPアドレス |
| `nat_private_dns` | `string` | NATインスタンスのプライベートDNS名 |
| `nat_subnet_id` | `string` | NATインスタンスのサブネットID |
| `nat_availability_zone` | `string` | NATインスタンスのアベイラビリティゾーン |

### Elastic IP情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `nat_eip_id` | `string` | NATインスタンスに割り当てたEIPのID |
| `nat_eip_arn` | `string` | NATインスタンスに割り当てたEIPのARN |
| `nat_eip` | `string` | NATインスタンスに割り当てたEIP |

### ストレージ情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `nat_root_block_device` | `object` | NATインスタンスのルートボリューム詳細情報 |

### CloudWatchアラーム

| 出力名 | 型 | 説明 |
|--------|----|------|
| `cloudwatch_alarms` | `object` | CloudWatchアラームの情報 |

## NAT設定の詳細

### 自動設定される機能

1. **IPフォワーディング**: `/proc/sys/net/ipv4/ip_forward`を有効化
2. **iptablesルール**: NATテーブルにPOSTROUTINGルールを追加
3. **ルール永続化**: iptablesルールを永続化
4. **SSH設定**: 公開鍵認証の設定
5. **セキュリティ強化**: セキュリティアップデートの自動化

### NATルールの例

```bash
# 自動設定されるiptablesルール
iptables -t nat -A POSTROUTING -o eth0 -s 10.0.0.0/16 -j MASQUERADE
```

## セキュリティ考慮事項

### 推奨事項

1. **IMDSv2の使用**: インスタンスメタデータサービスのセキュリティ強化
2. **ボリューム暗号化**: データ保護のため暗号化を有効化
3. **最小権限の原則**: セキュリティグループで必要最小限の通信のみ許可
4. **定期的な更新**: セキュリティパッチの自動適用

### 注意事項

- NATインスタンスは単一障害点となる可能性があります
- 高可用性が必要な場合は複数のNATインスタンスを検討
- 適切なセキュリティグループ設定が重要

## コスト最適化

### NAT Gatewayとの比較

| 項目 | NAT Instance | NAT Gateway |
|------|-------------|-------------|
| コスト | 低（t3.nano: ~$3.5/月） | 高（~$45/月） |
| 可用性 | 手動管理 | 自動管理 |
| カスタマイズ | 可能 | 制限あり |
| メンテナンス | 必要 | 不要 |

### 推奨設定

```hcl
# コスト最適化の例
module "nat_instance" {
  source = "./modules/nat-instance"
  
  instance_type = "t3.nano"  # 最小インスタンスタイプ
  root_volume_size = 8       # 最小ボリュームサイズ
  enable_detailed_monitoring = false  # 詳細モニタリング無効
}
```

## トラブルシューティング

### よくある問題

#### 1. NATインスタンスが動作しない

**原因**: iptablesルールが正しく設定されていない

**解決方法**:
```bash
# NATインスタンスにSSH接続
ssh ec2-user@<nat-instance-ip>

# iptablesルールの確認
sudo iptables -t nat -L POSTROUTING -n

# IPフォワーディングの確認
cat /proc/sys/net/ipv4/ip_forward
```

#### 2. プライベートサブネットからインターネットアクセスできない

**原因**: ルートテーブルの設定が不適切

**解決方法**:
```hcl
# ルートテーブルの設定確認
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.nat_instance.nat_instance_network_interface_id
}
```

#### 3. SSH接続ができない

**原因**: SSH設定の不備

**解決方法**:
```bash
# SSH設定の確認
ssh ec2-user@<nat-instance-ip> "ls -la ~/.ssh/"

# SSHサービスの確認
ssh ec2-user@<nat-instance-ip> "sudo systemctl status sshd"
```

## 更新履歴

- **v1.0.0**: 初回リリース
  - 基本的なNATインスタンス機能
  - 自動NAT設定
  - セキュリティ強化
  - CloudWatchアラーム統合
  - 詳細なモニタリング機能

## ライセンス

このモジュールは学習目的で作成されており、個人利用を想定しています。 