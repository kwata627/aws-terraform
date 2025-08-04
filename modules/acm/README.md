# ACM Certificate Module

## 概要

このモジュールはAWS Certificate Manager (ACM) を使用してSSL/TLS証明書を作成し、HTTPS通信を有効にします。CloudFrontとの統合を考慮してus-east-1リージョンでの証明書作成を想定しています。

## 特徴

- **DNS検証方式**: より安全で自動化しやすい証明書検証
- **ワイルドカード証明書**: サブドメインもカバーする柔軟な証明書
- **自動更新**: ACMによる自動的な証明書更新
- **適切なライフサイクル管理**: ダウンタイムを最小化する更新戦略
- **柔軟なタグ管理**: プロジェクト管理に適したタグ設定

## 使用方法

### 基本的な使用例

```hcl
module "acm" {
  source = "./modules/acm"
  
  project     = "my-project"
  domain_name = "example.com"
  
  providers = {
    aws = aws.us_east_1
  }
}
```

### 高度な設定例

```hcl
module "acm" {
  source = "./modules/acm"
  
  project     = "my-project"
  domain_name = "example.com"
  environment = "production"
  
  # カスタムSANの追加
  subject_alternative_names = [
    "api.example.com",
    "admin.example.com"
  ]
  
  # ワイルドカード証明書を無効化
  enable_wildcard = false
  
  # カスタムタグ
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Compliance  = "PCI-DSS"
  }
  
  providers = {
    aws = aws.us_east_1
  }
}
```

## 入力変数

### 必須変数

| 変数名 | 型 | 説明 | 例 |
|--------|----|----|-----|
| `project` | `string` | プロジェクト名（リソース名のprefix用） | `"my-project"` |
| `domain_name` | `string` | SSL証明書を発行するドメイン名 | `"example.com"` |

### オプション変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|----|-----------|------|
| `environment` | `string` | `"production"` | 環境名（dev, staging, production, test） |
| `subject_alternative_names` | `list(string)` | `[]` | サブジェクト代替名（SAN）のリスト |
| `tags` | `map(string)` | `{}` | 追加のタグ |
| `validation_method` | `string` | `"DNS"` | 証明書の検証方式（DNSまたはEMAIL） |
| `enable_wildcard` | `bool` | `true` | ワイルドカード証明書を有効にするかどうか |

## 出力値

### 証明書情報

| 出力名 | 型 | 説明 |
|--------|----|------|
| `certificate_arn` | `string` | 作成したACM証明書のARN |
| `certificate_domain_name` | `string` | 証明書のプライマリドメイン名 |
| `certificate_status` | `string` | 証明書の現在のステータス |
| `certificate_validation_method` | `string` | 証明書の検証方式 |

### 検証レコード

| 出力名 | 型 | 説明 |
|--------|----|------|
| `validation_records` | `map(object)` | DNS検証用のレコード情報 |
| `validation_record_names` | `list(string)` | 検証用DNSレコードの名前一覧 |
| `validation_record_values` | `list(string)` | 検証用DNSレコードの値一覧 |

### 証明書詳細

| 出力名 | 型 | 説明 |
|--------|----|------|
| `subject_alternative_names` | `list(string)` | 証明書に含まれるSANのリスト |
| `certificate_not_before` | `string` | 証明書の有効開始日 |
| `certificate_not_after` | `string` | 証明書の有効期限 |

## 前提条件

### 必要なプロバイダー設定

```hcl
# us-east-1リージョンのプロバイダー設定
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

### Route53との統合例

```hcl
# ACMモジュールの呼び出し
module "acm" {
  source = "./modules/acm"
  
  project     = var.project
  domain_name = var.domain_name
  
  providers = {
    aws = aws.us_east_1
  }
}

# Route53での検証レコード作成
resource "aws_route53_record" "cert_validation" {
  for_each = module.acm.validation_records
  
  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}
```

## セキュリティ考慮事項

### 推奨事項

1. **DNS検証の使用**: メール検証よりも安全で自動化しやすい
2. **ワイルドカード証明書の慎重な使用**: 必要最小限の範囲でのみ使用
3. **適切なタグ付け**: セキュリティ監査とコスト管理のため
4. **定期的な証明書監査**: 有効期限と使用状況の確認

### 注意事項

- 証明書の検証完了まで数分かかる場合があります
- 検証が完了するまで、証明書は使用できません
- 検証失敗時は、DNSレコードの設定を確認してください

## トラブルシューティング

### よくある問題

#### 1. 証明書の検証が失敗する

**原因**: DNSレコードが正しく設定されていない

**解決方法**:
```bash
# 検証レコードの確認
terraform output -json acm_validation_records

# DNSレコードの手動確認
dig +short _acm-validation.example.com CNAME
```

#### 2. CloudFrontで証明書が使用できない

**原因**: 証明書がus-east-1リージョンで作成されていない

**解決方法**:
```hcl
# プロバイダーの設定確認
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

#### 3. ワイルドカード証明書が期待通りに動作しない

**原因**: SANの設定が不適切

**解決方法**:
```hcl
# 明示的にワイルドカードを追加
subject_alternative_names = ["*.example.com"]
```

## 更新履歴

- **v1.0.0**: 初回リリース
  - DNS検証方式の実装
  - ワイルドカード証明書対応
  - 柔軟なタグ管理
  - 詳細な出力値の提供

## ライセンス

このモジュールは学習目的で作成されており、個人利用を想定しています。 