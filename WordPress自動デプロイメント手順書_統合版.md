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
- **自動デプロイメントスクリプト**: `scripts/auto_deployment.sh`
- **ロールバックスクリプト**: `scripts/rollback.sh`
- **初期設定スクリプト**: `scripts/setup_deployment.sh`
- **設定ファイル**: `deployment_config.json`
- **テストスクリプト**: `scripts/test_deployment.sh`

### 必要なツール
- AWS CLI
- jq（JSONパーサー）
- MySQLクライアント
- SSHクライアント

---

## 初期設定

### 1. システムの初期化

```bash
# 初期設定スクリプトの実行
./scripts/setup_deployment.sh
```

このスクリプトは以下を実行します：
- 必要なツールのインストール（jq、AWS CLI、MySQLクライアント）
- 設定ファイルの作成
- SSH鍵の設定
- 実行権限の付与

### 2. 環境テスト

```bash
# デプロイメントシステムのテスト
./scripts/test_deployment.sh
```

---

## 設定ファイル

### deployment_config.json の設定

```json
{
    "production": {
        "ec2_instance_id": "i-xxxxxxxxxxxxxxxxx",
        "rds_identifier": "wp-shamo-rds",
        "wordpress_url": "http://your-domain.com",
        "backup_retention_days": 7
    },
    "validation": {
        "ec2_instance_id": "i-yyyyyyyyyyyyyyyyy",
        "rds_identifier": "wp-shamo-rds-validation",
        "wordpress_url": "http://validation-ip",
        "test_timeout_minutes": 30
    },
    "deployment": {
        "auto_approve": false,
        "rollback_on_failure": true,
        "notification_email": "admin@example.com"
    }
}
```

### 設定項目の説明

#### production（本番環境）
- `ec2_instance_id`: 本番EC2インスタンスID
- `rds_identifier`: 本番RDS識別子
- `wordpress_url`: 本番WordPressサイトのURL
- `backup_retention_days`: バックアップ保持日数

#### validation（検証環境）
- `ec2_instance_id`: 検証EC2インスタンスID
- `rds_identifier`: 検証RDS識別子
- `wordpress_url`: 検証WordPressサイトのURL
- `test_timeout_minutes`: テストタイムアウト（分）

#### deployment（デプロイメント設定）
- `auto_approve`: 自動承認（true/false）
- `rollback_on_failure`: 失敗時のロールバック（true/false）
- `notification_email`: 通知メールアドレス

---

## デプロイメントフロー

### 基本的なデプロイメント実行

```bash
# 自動デプロイメントの実行
./scripts/auto_deployment.sh
```

### デプロイメントプロセスの詳細

#### ステップ1: スナップショット作成
- 本番環境のRDSスナップショットを作成
- タイムスタンプ付きで識別

#### ステップ2: 検証環境の起動
- 検証用EC2インスタンスを起動
- スナップショットから検証用RDSを復元

#### ステップ3: 検証環境の準備完了待機
- EC2インスタンスの起動完了を待機
- RDSインスタンスの利用可能状態を待機

#### ステップ4: 検証環境でのテスト
- WordPressサイトの動作確認
- 管理画面のアクセス確認
- データベース接続確認

#### ステップ5: ユーザー確認
- 自動承認でない場合、ユーザーの確認を求める
- 確認後、本番環境への反映を実行

#### ステップ6: 本番環境への反映
- 本番環境のバックアップ作成
- 検証環境から本番環境へのデータ同期
- WordPressファイルの同期

#### ステップ7: 本番環境の動作確認
- サイトの動作確認
- 管理画面のアクセス確認

#### ステップ8: 検証環境の停止
- 検証用EC2インスタンスの停止
- 検証用RDSインスタンスの停止

#### ステップ9: クリーンアップ
- 一時ファイルの削除
- ログファイルの保存

---

## ロールバック機能

デプロイメントが失敗した場合、ロールバックスクリプトを使用して本番環境を元の状態に戻すことができます：

```bash
# ロールバックの実行
./scripts/rollback.sh
```

### ロールバックプロセス
1. 最新のスナップショットを取得
2. 本番環境のRDSを停止
3. スナップショットから復元
4. WordPressファイルの復元
5. 動作確認

---

## ログとモニタリング

### ログファイル
- デプロイメントログ: `deployment_YYYYMMDD_HHMMSS.log`
- ロールバックログ: `rollback_YYYYMMDD_HHMMSS.log`

### ログの確認
```bash
# 最新のデプロイメントログを確認
tail -f deployment_*.log

# ロールバックログを確認
tail -f rollback_*.log
```

---

## セキュリティ考慮事項

### 1. アクセス制御
- AWS認証情報の適切な管理
- SSH鍵の安全な保管
- 最小権限の原則に従ったIAM設定

### 2. データ保護
- 自動バックアップの作成
- スナップショットの暗号化
- 機密情報の適切な管理

### 3. 監査ログ
- すべての操作のログ記録
- 変更履歴の追跡
- アクセスログの監視

---

## トラブルシューティング

### よくある問題と対処法

#### 1. AWS認証情報エラー
```bash
# AWS認証情報の確認
aws sts get-caller-identity

# 認証情報の設定
aws configure
```

#### 2. SSH接続エラー
```bash
# SSH鍵の確認
ls -la ~/.ssh/id_rsa

# SSH鍵の再設定
terraform output -raw ssh_private_key > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

#### 3. データベース接続エラー
```bash
# RDSエンドポイントの確認
aws rds describe-db-instances --db-instance-identifier wp-shamo-rds

# セキュリティグループの確認
aws ec2 describe-security-groups --group-ids [セキュリティグループID]
```

#### 4. スナップショット作成エラー
```bash
# 利用可能なスナップショットの確認
aws rds describe-db-snapshots --db-instance-identifier wp-shamo-rds

# 手動でスナップショットを作成
aws rds create-db-snapshot --db-instance-identifier wp-shamo-rds --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)
```

#### 5. デプロイメント中にエラーが発生
```bash
# ログの確認
tail -f deployment_*.log

# 手動でのロールバック
./scripts/rollback.sh

# 問題の特定と修正後、再度デプロイメント実行
./scripts/auto_deployment.sh
```

---

## ベストプラクティス

### 1. デプロイメント前の確認
- 設定ファイルの内容確認
- 環境テストの実行
- バックアップの確認

### 2. 段階的なデプロイメント
- 小さな変更から開始
- 各段階での動作確認
- 問題発生時の迅速な対応

### 3. 監視とアラート
- デプロイメント後の監視
- パフォーマンスの確認
- エラーアラートの設定

### 4. ドキュメント管理
- 変更履歴の記録
- 設定変更の記録
- トラブルシューティングの記録

---

## 定期メンテナンス

### 毎週の確認
- [ ] ログファイルの確認
- [ ] バックアップの確認
- [ ] 設定ファイルの更新確認

### 毎月の確認
- [ ] スナップショットの整理
- [ ] セキュリティ設定の確認
- [ ] パフォーマンスの確認

### 四半期の確認
- [ ] システム全体の見直し
- [ ] セキュリティ監査
- [ ] ドキュメントの更新

---

## 注意事項

1. **必ず検証環境でテストしてから本番環境に反映**
2. **デプロイメント前のバックアップ確認**
3. **緊急時以外は営業時間内に実行**
4. **すべての操作のログ記録**
5. **セキュリティを最優先に考慮**

---

*この手順書は随時更新されます。最新版を確認してから作業を開始してください。* 