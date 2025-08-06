# GitHub Secrets 設定ガイド

このドキュメントでは、GitHub Actionsワークフローで使用するSecretsの設定方法を説明します。

## 必要なSecrets

### AWS認証情報
| Secret名 | 説明 | 取得方法 |
|---------|------|----------|
| `AWS_ACCESS_KEY_ID` | AWSアクセスキーID | AWS IAMコンソールで作成 |
| `AWS_SECRET_ACCESS_KEY` | AWSシークレットアクセスキー | AWS IAMコンソールで作成 |
| `AWS_REGION` | AWSリージョン | 例: `ap-northeast-1` |

### SSH接続情報
| Secret名 | 説明 | 取得方法 |
|---------|------|----------|
| `SSH_PRIVATE_KEY` | SSH秘密鍵 | Terraformで生成された秘密鍵 |
| `WORDPRESS_HOST` | WordPressサーバーのIPアドレス | EC2インスタンスのパブリックIP |

### リソース識別子
| Secret名 | 説明 | 取得方法 |
|---------|------|----------|
| `PRODUCTION_EC2_ID` | 本番EC2インスタンスID | AWS EC2コンソールまたはTerraform出力 |
| `PRODUCTION_RDS_ID` | 本番RDS識別子 | AWS RDSコンソールまたはTerraform出力 |
| `VALIDATION_EC2_ID` | 検証用EC2インスタンスID | AWS EC2コンソールまたはTerraform出力 |
| `VALIDATION_RDS_ID` | 検証用RDS識別子 | AWS RDSコンソールまたはTerraform出力 |

### URL情報
| Secret名 | 説明 | 取得方法 |
|---------|------|----------|
| `PRODUCTION_WORDPRESS_URL` | 本番WordPressサイトのURL | 例: `https://example.com` |

### 承認設定
| Secret名 | 説明 | 設定値 |
|---------|------|--------|
| `APPROVAL_SECRET` | デプロイメント承認用シークレット | 任意の文字列 |
| `APPROVERS` | デプロイメント承認者 | GitHubユーザー名（カンマ区切り） |
| `ROLLBACK_APPROVAL_SECRET` | ロールバック承認用シークレット | 任意の文字列 |
| `ROLLBACK_APPROVERS` | ロールバック承認者 | GitHubユーザー名（カンマ区切り） |

## 設定手順

### 1. AWS認証情報の設定

#### IAMユーザーの作成
1. AWS IAMコンソールにアクセス
2. 新しいユーザーを作成
3. 以下のポリシーをアタッチ：
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:*",
           "rds:*",
           "s3:*",
           "iam:GetUser"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
4. アクセスキーを作成
5. アクセスキーIDとシークレットアクセスキーをコピー

#### GitHub Secretsの設定
1. GitHubリポジトリのSettings → Secrets and variables → Actions
2. "New repository secret"をクリック
3. 以下のSecretsを追加：
   - `AWS_ACCESS_KEY_ID`: アクセスキーID
   - `AWS_SECRET_ACCESS_KEY`: シークレットアクセスキー
   - `AWS_REGION`: `ap-northeast-1`

### 2. SSH鍵の設定

#### SSH秘密鍵の取得
```bash
# Terraformで生成された秘密鍵を取得
terraform output -raw ssh_private_key
```

#### GitHub Secretsの設定
1. 取得した秘密鍵を`SSH_PRIVATE_KEY`として設定
2. WordPressサーバーのIPアドレスを`WORDPRESS_HOST`として設定

### 3. リソース識別子の設定

#### Terraform出力から取得
```bash
# EC2インスタンスID
terraform output -raw ec2_instance_id

# RDS識別子
terraform output -raw rds_identifier

# 検証用EC2インスタンスID
terraform output -raw validation_ec2_instance_id

# 検証用RDS識別子
terraform output -raw validation_rds_identifier
```

#### GitHub Secretsの設定
- `PRODUCTION_EC2_ID`: 本番EC2インスタンスID
- `PRODUCTION_RDS_ID`: 本番RDS識別子
- `VALIDATION_EC2_ID`: 検証用EC2インスタンスID
- `VALIDATION_RDS_ID`: 検証用RDS識別子

### 4. 承認設定の設定

#### 承認シークレットの生成
```bash
# デプロイメント承認用シークレット
openssl rand -hex 32

# ロールバック承認用シークレット
openssl rand -hex 32
```

#### GitHub Secretsの設定
- `APPROVAL_SECRET`: デプロイメント承認用シークレット
- `APPROVERS`: 承認者のGitHubユーザー名（例: `admin,manager`）
- `ROLLBACK_APPROVAL_SECRET`: ロールバック承認用シークレット
- `ROLLBACK_APPROVERS`: ロールバック承認者のGitHubユーザー名

## 設定確認

### 1. Secretsの確認
```bash
# GitHub CLIを使用してSecretsを確認
gh secret list
```

### 2. ワークフローのテスト
1. GitHubリポジトリのActionsタブにアクセス
2. "WordPress Environment Setup"ワークフローを選択
3. "Run workflow"をクリック
4. 手動実行でテスト

### 3. 接続テスト
```bash
# SSH接続のテスト
ssh -i ~/.ssh/id_rsa ec2-user@$WORDPRESS_HOST "echo 'SSH connection successful'"

# AWS CLIのテスト
aws sts get-caller-identity
```

## トラブルシューティング

### よくある問題

#### 1. AWS認証情報エラー
```
Error: The security token included in the request is invalid
```
**解決方法**: AWS認証情報を再設定

#### 2. SSH接続エラー
```
Permission denied (publickey)
```
**解決方法**: SSH秘密鍵の確認と権限設定

#### 3. リソースが見つからないエラー
```
Error: The specified DB instance does not exist
```
**解決方法**: リソース識別子の確認

#### 4. 承認エラー
```
Error: Approval required
```
**解決方法**: 承認者の設定確認

## セキュリティ注意事項

### 1. 最小権限の原則
- IAMユーザーには必要最小限の権限のみ付与
- 定期的に権限の見直しを実施

### 2. シークレットの管理
- シークレットは定期的にローテーション
- 不要になったシークレットは削除

### 3. アクセス制御
- 承認者は必要最小限に限定
- 承認プロセスは記録を残す

### 4. 監査ログ
- すべての操作はログに記録
- 定期的にログの確認を実施

## 更新手順

### 1. 新しいリソースの追加
1. 新しいSecretを追加
2. ワークフローファイルを更新
3. テスト実行

### 2. 既存Secretsの更新
1. 古いSecretを削除
2. 新しいSecretを追加
3. ワークフローの再実行

### 3. 権限の変更
1. IAMポリシーを更新
2. 新しいアクセスキーを作成
3. GitHub Secretsを更新 