# Network Module

このモジュールは、AWS VPCとサブネットを作成し、WordPress環境のネットワーク基盤を提供します。マルチAZ対応とセキュリティ強化を考慮した設計となっています。

## 特徴

- **マルチAZ対応**: 複数のアベイラビリティゾーンにサブネットを配置
- **セキュリティ強化**: Network ACL、VPCエンドポイント、Flow Logs対応
- **柔軟なサブネット設計**: カスタマイズ可能なサブネット設定
- **自動ルーティング設定**: Internet GatewayとNATルートの自動設定
- **詳細なタグ管理**: リソース管理のための包括的なタグ付け

## 使用方法

### 基本的な使用例

```hcl
module "network" {
  source = "./modules/network"
  
  project = "my-wordpress"
  
  vpc_cidr = "10.0.0.0/16"
  
  public_subnets = [
    {
      cidr = "10.0.1.0/24"
      az   = "ap-northeast-1a"
    },
    {
      cidr = "10.0.2.0/24"
      az   = "ap-northeast-1c"
    }
  ]
  
  private_subnets = [
    {
      cidr = "10.0.10.0/24"
      az   = "ap-northeast-1a"
    },
    {
      cidr = "10.0.11.0/24"
      az   = "ap-northeast-1c"
    }
  ]
}
```

### 高度な設定例

```hcl
module "network" {
  source = "./modules/network"
  
  project     = "my-wordpress"
  environment = "production"
  
  vpc_cidr = "10.0.0.0/16"
  
  public_subnets = [
    {
      cidr = "10.0.1.0/24"
      az   = "ap-northeast-1a"
      name = "public-subnet-1a"
    },
    {
      cidr = "10.0.2.0/24"
      az   = "ap-northeast-1c"
      name = "public-subnet-1c"
    }
  ]
  
  private_subnets = [
    {
      cidr = "10.0.10.0/24"
      az   = "ap-northeast-1a"
      name = "private-subnet-1a"
    },
    {
      cidr = "10.0.11.0/24"
      az   = "ap-northeast-1c"
      name = "private-subnet-1c"
    }
  ]
  
  # セキュリティ機能の有効化
  enable_network_acls = true
  enable_vpc_endpoints = true
  enable_flow_logs     = true
  
  # NATインスタンスの設定
  nat_instance_network_interface_id = module.nat_instance.network_interface_id
  enable_nat_route = true
  
  # タグの追加
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "true"
  }
}
```

## 入力変数

| 名前 | 説明 | 型 | デフォルト | 必須 |
|------|------|------|------|------|
| project | プロジェクト名（リソース名のprefix用） | `string` | - | はい |
| environment | 環境名 | `string` | `"production"` | いいえ |
| vpc_cidr | VPCのCIDRブロック | `string` | - | はい |
| public_subnets | パブリックサブネットの設定 | `list(object)` | - | はい |
| private_subnets | プライベートサブネットの設定 | `list(object)` | - | はい |
| nat_instance_network_interface_id | NATインスタンスのネットワークインターフェースID | `string` | `""` | いいえ |
| enable_nat_route | NATルートの有効化 | `bool` | `true` | いいえ |
| enable_network_acls | Network ACLの有効化 | `bool` | `false` | いいえ |
| enable_vpc_endpoints | VPCエンドポイントの有効化 | `bool` | `false` | いいえ |
| aws_region | AWSリージョン | `string` | `"ap-northeast-1"` | いいえ |
| tags | 追加のタグ | `map(string)` | `{}` | いいえ |
| enable_flow_logs | VPC Flow Logsの有効化 | `bool` | `false` | いいえ |
| flow_log_retention_days | Flow Logsの保持期間（日数） | `number` | `30` | いいえ |

### サブネット設定オブジェクト

```hcl
object({
  cidr = string
  az   = string
  name = optional(string)
})
```

## 出力

| 名前 | 説明 |
|------|------|
| vpc_id | 作成されたVPCのID |
| vpc_cidr_block | VPCのCIDRブロック |
| vpc_arn | VPCのARN |
| internet_gateway_id | Internet GatewayのID |
| public_subnet_ids | パブリックサブネットのID一覧 |
| public_subnet_arns | パブリックサブネットのARN一覧 |
| private_subnet_ids | プライベートサブネットのID一覧 |
| private_subnet_arns | プライベートサブネットのARN一覧 |
| public_route_table_id | パブリックルートテーブルのID |
| private_route_table_id | プライベートルートテーブルのID |
| network_acl_ids | Network ACLのID一覧（有効な場合） |
| vpc_endpoint_ids | VPCエンドポイントのID一覧（有効な場合） |
| flow_log_id | VPC Flow LogのID（有効な場合） |

### 後方互換性のための出力

| 名前 | 説明 |
|------|------|
| public_subnet_id | 最初のパブリックサブネットのID（後方互換性） |
| private_subnet_id_1 | 最初のプライベートサブネットのID（後方互換性） |
| private_subnet_id_2 | 2番目のプライベートサブネットのID（後方互換性） |

## セキュリティ機能

### Network ACL

Network ACLを有効にすると、以下のルールが設定されます：

**パブリックサブネット:**
- インバウンド: HTTP(80), HTTPS(443), SSH(22)
- アウトバウンド: すべて許可

**プライベートサブネット:**
- インバウンド: VPC内からの通信のみ許可
- アウトバウンド: すべて許可

### VPCエンドポイント

VPCエンドポイントを有効にすると、以下のエンドポイントが作成されます：
- S3エンドポイント
- DynamoDBエンドポイント

### VPC Flow Logs

Flow Logsを有効にすると、VPC内のすべてのトラフィックがCloudWatch Logsに記録されます。

## ベストプラクティス

1. **CIDR設計**: 重複しないCIDRブロックを使用
2. **マルチAZ**: 高可用性のため複数のAZを使用
3. **セキュリティ**: 本番環境ではNetwork ACLとFlow Logsを有効化
4. **タグ付け**: リソース管理のため適切なタグを設定
5. **命名規則**: 一貫した命名規則を使用

## 注意事項

- NATインスタンスのネットワークインターフェースIDは、NATインスタンスモジュールから取得してください
- VPCエンドポイントは追加料金が発生する場合があります
- Flow Logsは大量のログデータを生成する可能性があります

## トラブルシューティング

### よくある問題

1. **CIDR重複エラー**: サブネットのCIDRが重複している場合
2. **AZ不一致**: 指定したAZが存在しない場合
3. **権限エラー**: IAM権限が不足している場合

### 解決方法

1. CIDRブロックを確認し、重複を解消
2. 有効なAZを指定
3. 必要なIAM権限を付与 