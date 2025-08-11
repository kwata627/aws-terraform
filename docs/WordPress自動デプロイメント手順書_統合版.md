# WordPress自動デプロイメントシステム手順書

## 目次
1. [概要](#概要)
2. [システム構成](#システム構成)
3. [初期設定](#初期設定)
4. [設定ファイル](#設定ファイル)
5. [デプロイメントフロー](#デプロイメントフロー)
6. [ロールバック機能](#ロールバック機能)
7. [ログとモニタリング](#ログとモニタリング)
8. [セキュリティ考慮事項](#セキュリティ考慮事項)
9. [トラブルシューティング](#トラブルシューティング)
10. [ベストプラクティス](#ベストプラクティス)

---

## 概要

このシステムは、検証環境でのテスト後に本番環境に自動的にWordPressコンテンツを反映させる自動デプロイメントシステムです。スナップショットを活用して安全な更新プロセスを実現します。

### デプロイメントフロー
```
1. 本番環境のスナップショット作成
2. 検証環境の起動（スナップショットから復元）
3. 検証環境でのテスト実行
4. ユーザー確認（自動承認でない場合）
5. 本番環境への反映
6. 本番環境の動作確認
7. 検証環境の停止
8. クリーンアップ
```

---

## システム構成

### 主要コンポーネント
- **自動デプロイメントスクリプト**: `scripts/deployment/auto_deployment.sh`
- **ロールバックスクリプト**: `scripts/maintenance/rollback.sh`
- **検証環境準備スクリプト**: `scripts/deployment/prepare_validation.sh`
- **本番環境デプロイスクリプト**: `scripts/deployment/deploy_to_production.sh`
- **設定ファイル**: `deployment_config.json`
- **共通ライブラリ**: `scripts/lib/common.sh`

### 必要なツール
- AWS CLI v2以上
- jq（JSONパーサー）
- MySQLクライアント
- SSHクライアント
- rsync（ファイル同期）

---

## 初期設定

### 1. システムの初期化

```bash
# 初期設定スクリプトの実行
./scripts/setup/initialize_deployment.sh
```

このスクリプトは以下を実行します：
- 必要なツールのインストール（jq、AWS CLI、MySQLクライアント）
- 設定ファイルの作成
- SSH鍵の設定
- 実行権限の付与

### 2. 環境テスト

```bash
# デプロイメントシステムのテスト
./scripts/deployment/test_deployment.sh
```

### 3. AWS認証情報の設定

```bash
# AWS認証情報の確認
aws sts get-caller-identity

# 認証情報の設定（必要な場合）
aws configure
```

---

## 設定ファイル

### deployment_config.json の設定

```json
{
    "production": {
        "ec2_instance_id": "i-xxxxxxxxxxxxxxxxx",
        "rds_identifier": "wp-example-rds",
        "wordpress_url": "https://example.com",
        "backup_retention_days": 7,
        "ssh_user": "ec2-user",
        "ssh_key_path": "~/.ssh/id_rsa"
    },
    "validation": {
        "ec2_instance_id": "i-yyyyyyyyyyyyyyyyy",
        "rds_identifier": "wp-example-rds-validation",
        "wordpress_url": "http://validation-ip",
        "test_timeout_minutes": 30,
        "ssh_user": "ec2-user",
        "ssh_key_path": "~/.ssh/id_rsa"
    },
    "deployment": {
        "auto_approve": false,
        "rollback_on_failure": true,
        "notification_email": "admin@example.com",
        "backup_before_deployment": true,
        "test_after_deployment": true
    },
    "aws": {
        "region": "ap-northeast-1",
        "profile": "default",
        "max_retries": 3
    }
}
```

**注意**: 実際の使用時は、このファイルをコピーして `deployment_config.json` として使用し、適切な値を設定してください。

### 設定項目の説明

#### production（本番環境）
- `ec2_instance_id`: 本番EC2インスタンスID
- `rds_identifier`: 本番RDS識別子
- `wordpress_url`: 本番WordPressサイトのURL
- `backup_retention_days`: バックアップ保持日数
- `ssh_user`: SSH接続ユーザー名
- `ssh_key_path`: SSH秘密鍵のパス

#### validation（検証環境）
- `ec2_instance_id`: 検証EC2インスタンスID
- `rds_identifier`: 検証RDS識別子
- `wordpress_url`: 検証WordPressサイトのURL
- `test_timeout_minutes`: テストタイムアウト（分）
- `ssh_user`: SSH接続ユーザー名
- `ssh_key_path`: SSH秘密鍵のパス

#### deployment（デプロイメント設定）
- `auto_approve`: 自動承認（true/false）
- `rollback_on_failure`: 失敗時のロールバック（true/false）
- `notification_email`: 通知メールアドレス
- `backup_before_deployment`: デプロイ前バックアップ（true/false）
- `test_after_deployment`: デプロイ後テスト（true/false）

#### aws（AWS設定）
- `region`: AWSリージョン
- `profile`: AWSプロファイル名
- `max_retries`: 最大リトライ回数

---

## デプロイメントフロー

### 基本的なデプロイメント実行

```bash
# 自動デプロイメントの実行
./scripts/deployment/auto_deployment.sh

# ドライラン（実際の変更なし）
./scripts/deployment/auto_deployment.sh --dry-run

# ヘルプの表示
./scripts/deployment/auto_deployment.sh --help
```

### デプロイメントプロセスの詳細

#### ステップ1: 事前チェック
- AWS認証情報の確認
- 設定ファイルの検証
- 必要なツールの確認
- ネットワーク接続の確認

#### ステップ2: スナップショット作成
- 本番環境のRDSスナップショットを作成
- タイムスタンプ付きで識別
- スナップショットの作成完了を待機

#### ステップ3: 検証環境の起動
- 検証用EC2インスタンスを起動
- スナップショットから検証用RDSを復元
- インスタンスの起動完了を待機

#### ステップ4: 検証環境の準備完了待機
- EC2インスタンスの起動完了を待機
- RDSインスタンスの利用可能状態を待機
- WordPressサイトの起動完了を待機

#### ステップ5: 検証環境でのテスト
- WordPressサイトの動作確認
- 管理画面のアクセス確認
- データベース接続確認
- 基本的な機能テスト

#### ステップ6: ユーザー確認
- 自動承認でない場合、ユーザーの確認を求める
- 確認後、本番環境への反映を実行

#### ステップ7: 本番環境への反映
- 本番環境のバックアップ作成
- 検証環境から本番環境へのデータ同期
- WordPressファイルの同期
- 設定ファイルの同期

#### ステップ8: 本番環境の動作確認
- サイトの動作確認
- 管理画面のアクセス確認
- データベース接続確認
- パフォーマンステスト

#### ステップ9: 検証環境の停止
- 検証用EC2インスタンスの停止
- 検証用RDSインスタンスの停止
- 一時リソースのクリーンアップ

#### ステップ10: クリーンアップ
- 一時ファイルの削除
- ログファイルの保存
- 通知の送信

---

## ロールバック機能

デプロイメントが失敗した場合、ロールバックスクリプトを使用して本番環境を元の状態に戻すことができます：

```bash
# ロールバックの実行
./scripts/maintenance/rollback.sh

# 特定のスナップショットからロールバック
./scripts/maintenance/rollback.sh --snapshot-id [スナップショットID]
```

### ロールバックプロセス
1. 最新のスナップショットを取得
2. 本番環境のRDSを停止
3. スナップショットから復元
4. WordPressファイルの復元
5. 動作確認

### ロールバックの確認事項
- [ ] データベースの復元完了
- [ ] WordPressファイルの復元完了
- [ ] サイトの動作確認
- [ ] 管理画面のアクセス確認

---

## ログとモニタリング

### ログファイル
- デプロイメントログ: `logs/deployment_YYYYMMDD_HHMMSS.log`
- ロールバックログ: `logs/rollback_YYYYMMDD_HHMMSS.log`
- エラーログ: `logs/error_YYYYMMDD_HHMMSS.log`

### ログの確認
```bash
# 最新のデプロイメントログを確認
tail -f logs/deployment_*.log

# ロールバックログを確認
tail -f logs/rollback_*.log

# エラーログを確認
tail -f logs/error_*.log
```

### モニタリング
```bash
# デプロイメント状態の確認
./scripts/deployment/check_deployment_status.sh

# リソース使用状況の確認
./scripts/maintenance/check_resources.sh
```

---

## セキュリティ考慮事項

### 1. アクセス制御
- AWS認証情報の適切な管理
- SSH鍵の安全な保管
- 最小権限の原則に従ったIAM設定
- セキュリティグループの適切な設定

### 2. データ保護
- 自動バックアップの作成
- スナップショットの暗号化
- 機密情報の適切な管理
- 転送時の暗号化

### 3. 監査ログ
- すべての操作のログ記録
- 変更履歴の追跡
- アクセスログの監視
- セキュリティイベントの記録

### 4. セキュリティベストプラクティス
- 定期的なセキュリティ更新
- 脆弱性スキャンの実施
- セキュリティ監査の実施
- インシデント対応計画の策定

---

## トラブルシューティング

### よくある問題と対処法

#### 1. AWS認証情報エラー
```bash
# AWS認証情報の確認
aws sts get-caller-identity

# 認証情報の設定
aws configure

# プロファイルの確認
aws configure list-profiles
```

#### 2. SSH接続エラー
```bash
# SSH鍵の確認
ls -la ~/.ssh/id_rsa

# SSH鍵の再設定
terraform output -raw ssh_private_key > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# SSH接続テスト
ssh -i ~/.ssh/id_rsa ec2-user@[EC2_IP] "echo 'SSH接続成功'"
```

#### 3. データベース接続エラー
```bash
# RDSエンドポイントの確認
aws rds describe-db-instances --db-instance-identifier wp-shamo-rds

# セキュリティグループの確認
aws ec2 describe-security-groups --group-ids [セキュリティグループID]

# データベース接続テスト
mysql -h [RDSエンドポイント] -u [ユーザー名] -p -e "SELECT 1;"
```

#### 4. スナップショット作成エラー
```bash
# 利用可能なスナップショットの確認
aws rds describe-db-snapshots --db-instance-identifier wp-example-rds

# 手動でスナップショットを作成
aws rds create-db-snapshot --db-instance-identifier wp-example-rds --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)

# スナップショットの状態確認
aws rds describe-db-snapshots --db-snapshot-identifier [スナップショットID]
```

#### 5. デプロイメント中にエラーが発生
```bash
# ログの確認
tail -f logs/deployment_*.log

# 手動でのロールバック
./scripts/maintenance/rollback.sh

# 問題の特定と修正後、再度デプロイメント実行
./scripts/deployment/auto_deployment.sh
```

#### 6. 検証環境が起動しない
```bash
# インスタンスの状態確認
aws ec2 describe-instances --instance-ids [検証用EC2のID]

# エラーログの確認
aws ec2 get-console-output --instance-id [検証用EC2のID]

# セキュリティグループの確認
aws ec2 describe-security-groups --group-ids [セキュリティグループID]
```

---

## ベストプラクティス

### 1. デプロイメント前の確認
- 設定ファイルの内容確認
- 環境テストの実行
- バックアップの確認
- セキュリティ設定の確認

### 2. 段階的なデプロイメント
- 小さな変更から開始
- 各段階での動作確認
- 問題発生時の迅速な対応
- ロールバック手順の確認

### 3. 監視とアラート
- デプロイメント後の監視
- パフォーマンスの確認
- エラーアラートの設定
- セキュリティイベントの監視

### 4. ドキュメント管理
- 変更履歴の記録
- 設定変更の記録
- トラブルシューティングの記録
- ベストプラクティスの共有

### 5. セキュリティ強化
- 定期的なセキュリティ更新
- 脆弱性スキャンの実施
- アクセス制御の強化
- 監査ログの確認

---

## 定期メンテナンス

### 毎週の確認
- [ ] ログファイルの確認
- [ ] バックアップの確認
- [ ] 設定ファイルの更新確認
- [ ] セキュリティ設定の確認

### 毎月の確認
- [ ] スナップショットの整理
- [ ] セキュリティ設定の確認
- [ ] パフォーマンスの確認
- [ ] コストの確認

### 四半期の確認
- [ ] システム全体の見直し
- [ ] セキュリティ監査
- [ ] ドキュメントの更新
- [ ] ベストプラクティスの見直し

---

## 注意事項

1. **必ず検証環境でテストしてから本番環境に反映**
2. **デプロイメント前のバックアップ確認**
3. **緊急時以外は営業時間内に実行**
4. **すべての操作のログ記録**
5. **セキュリティを最優先に考慮**
6. **定期的なセキュリティ監査の実施**
7. **パスワードの定期変更の実施**
8. **アクセス制御の強化**

---

*この手順書は随時更新されます。最新版を確認してから作業を開始してください。* 