# WordPress自動デプロイメントシステム手順書

## 目次
1. [概要](#概要)
2. [システム構成](#システム構成)
3. [初期設定](#初期設定)
4. [GitHub Actions設定](#github-actions設定)
5. [デプロイメントフロー](#デプロイメントフロー)
6. [ロールバック機能](#ロールバック機能)
7. [ログとモニタリング](#ログとモニタリング)
8. [セキュリティ考慮事項](#セキュリティ考慮事項)
9. [トラブルシューティング](#トラブルシューティング)
10. [ベストプラクティス](#ベストプラクティス)

---

## 概要

このシステムは、GitHub Actionsを使用して検証環境でのテスト後に本番環境に自動的にWordPressコンテンツを反映させる自動デプロイメントシステムです。スナップショットを活用して安全な更新プロセスを実現します。

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
- **自動デプロイメントワークフロー**: `.github/workflows/auto-deployment.yml`
- **ロールバックワークフロー**: `.github/workflows/rollback.yml`
- **検証環境準備ワークフロー**: `.github/workflows/prepare-validation.yml`
- **本番環境デプロイワークフロー**: `.github/workflows/deploy-to-production.yml`
- **設定ファイル**: `deployment_config.json`
- **GitHub Secrets**: 認証情報の安全な管理

### 必要なツール
- GitHub Actions（自動実行環境）
- AWS CLI v2以上
- jq（JSONパーサー）
- MySQLクライアント
- SSHクライアント
- rsync（ファイル同期）

---

## 初期設定

### 1. GitHub Secretsの設定

GitHubリポジトリの **Settings** → **Secrets and variables** → **Actions** で以下のシークレットを設定してください：

#### 必須シークレット
- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー
- `AWS_REGION`: AWSリージョン（例: `ap-northeast-1`）
- `SSH_PRIVATE_KEY`: SSH秘密鍵
- `WORDPRESS_HOST`: WordPressサーバーのIPアドレス

#### オプションシークレット
- `PRODUCTION_EC2_ID`: 本番EC2インスタンスID
- `PRODUCTION_RDS_ID`: 本番RDS識別子
- `VALIDATION_EC2_ID`: 検証用EC2インスタンスID
- `VALIDATION_RDS_ID`: 検証用RDS識別子
- `APPROVAL_SECRET`: デプロイメント承認用シークレット
- `APPROVERS`: デプロイメント承認者（GitHubユーザー名、カンマ区切り）
- `ROLLBACK_APPROVAL_SECRET`: ロールバック承認用シークレット
- `ROLLBACK_APPROVERS`: ロールバック承認者（GitHubユーザー名、カンマ区切り）

### 2. デプロイメントシステムの初期化

```bash
# GitHub Actionsワークフローを手動実行
# .github/workflows/setup-deployment.yml を実行
```

このワークフローは以下を実行します：
- 設定ファイルの生成
- SSH鍵の設定
- 環境検証
- アーティファクトのアップロード

### 3. 環境テスト

```bash
# GitHub Actionsワークフローを手動実行
# .github/workflows/wordpress-setup.yml を実行
```

---

## GitHub Actions設定

### 利用可能なワークフロー

#### 1. WordPress Environment Setup
- **ファイル**: `.github/workflows/wordpress-setup.yml`
- **目的**: WordPress環境の構築と設定
- **トリガー**: 手動実行、Ansibleファイル変更
- **機能**: 
  - インベントリの自動生成
  - 接続テスト
  - Ansibleプレイブックの実行
  - WordPressサイトの動作確認

#### 2. Auto Deployment
- **ファイル**: `.github/workflows/auto-deployment.yml`
- **目的**: 検証環境でのテスト後に本番環境への自動デプロイ
- **トリガー**: WordPressコンテンツ変更、手動実行
- **機能**:
  - 本番環境のスナップショット作成
  - 検証環境の起動と復元
  - 検証環境でのテスト実行
  - 承認フロー（手動/自動）
  - 本番環境への反映
  - 検証環境のクリーンアップ

#### 3. Rollback Deployment
- **ファイル**: `.github/workflows/rollback.yml`
- **目的**: 問題発生時の本番環境のロールバック
- **トリガー**: 手動実行
- **機能**:
  - ロールバック前のバックアップ作成
  - 指定したスナップショットからの復元
  - ロールバック後の動作確認
  - 承認フロー（手動/自動）

### 使用方法

#### GitHub Actionsでの実行
1. **手動実行**: GitHubリポジトリのActionsタブから実行
2. **自動実行**: コードプッシュ時に自動実行
3. **承認フロー**: 設定に応じて手動承認が必要

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
        "ssh_key_path": "~/.ssh/id_rsa",
        "db_password": "your-secure-password-here"
    },
    "validation": {
        "ec2_instance_id": "i-yyyyyyyyyyyyyyyyy",
        "rds_identifier": "wp-example-rds-validation",
        "wordpress_url": "http://validation-ip",
        "test_timeout_minutes": 30,
        "ssh_user": "ec2-user",
        "ssh_key_path": "~/.ssh/id_rsa",
        "db_password": "your-secure-password-here"
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

### 設定項目の説明

#### production（本番環境）
- `ec2_instance_id`: 本番EC2インスタンスID
- `rds_identifier`: 本番RDS識別子
- `wordpress_url`: WordPressサイトのURL
- `backup_retention_days`: バックアップ保持日数
- `ssh_user`: SSH接続ユーザー名
- `ssh_key_path`: SSH秘密鍵のパス
- `db_password`: データベースパスワード

#### validation（検証環境）
- `ec2_instance_id`: 検証用EC2インスタンスID
- `rds_identifier`: 検証用RDS識別子
- `wordpress_url`: 検証環境のWordPress URL
- `test_timeout_minutes`: テストタイムアウト時間
- `ssh_user`: SSH接続ユーザー名
- `ssh_key_path`: SSH秘密鍵のパス
- `db_password`: データベースパスワード

#### deployment（デプロイメント設定）
- `auto_approve`: 自動承認の有効/無効
- `rollback_on_failure`: 失敗時の自動ロールバック
- `notification_email`: 通知メールアドレス
- `backup_before_deployment`: デプロイ前のバックアップ作成
- `test_after_deployment`: デプロイ後のテスト実行

#### aws（AWS設定）
- `region`: AWSリージョン
- `profile`: AWSプロファイル名
- `max_retries`: 最大リトライ回数

---

## デプロイメントフロー

### 1. 手動デプロイメント

#### GitHub Actionsでの実行
1. GitHubリポジトリの **Actions** タブにアクセス
2. **Auto Deployment** ワークフローを選択
3. **Run workflow** をクリック
4. 必要なパラメータを入力：
   - `environment`: デプロイ対象環境（production）
   - `auto_approve`: 自動承認の有効/無効
   - `dry_run`: ドライランの有効/無効
   - `backup_before_deployment`: デプロイ前バックアップの有効/無効
5. **Run workflow** をクリックして実行開始

#### 実行される処理
1. **事前チェック**
   - AWS認証情報の確認
   - リソース存在確認
   - 接続テスト

2. **バックアップ作成**
   - 本番環境のスナップショット作成
   - バックアップの検証

3. **検証環境準備**
   - 検証環境の起動
   - スナップショットからの復元
   - 基本的な動作確認

4. **承認フロー**
   - 自動承認の場合：即座に続行
   - 手動承認の場合：承認者の確認待機

5. **本番環境反映**
   - 本番環境への変更反映
   - 動作確認
   - 検証環境のクリーンアップ

### 2. 自動デプロイメント

#### トリガー設定
- WordPressコンテンツの変更を検知
- 特定のブランチへのプッシュ
- スケジュール実行

#### 実行条件
- 検証環境でのテスト成功
- 承認者の承認（設定による）
- エラーチェックの通過

---

## ロールバック機能

### 1. 手動ロールバック

#### GitHub Actionsでの実行
1. GitHubリポジトリの **Actions** タブにアクセス
2. **Rollback Deployment** ワークフローを選択
3. **Run workflow** をクリック
4. 必要なパラメータを入力：
   - `snapshot_id`: 復元するスナップショットID
   - `force_rollback`: 強制ロールバックの有効/無効
   - `backup_before_rollback`: ロールバック前バックアップの有効/無効
5. **Run workflow** をクリックして実行開始

#### 実行される処理
1. **事前チェック**
   - スナップショットの存在確認
   - 本番環境の状態確認

2. **バックアップ作成**
   - 現在の状態のバックアップ作成
   - バックアップの検証

3. **承認フロー**
   - 自動承認の場合：即座に続行
   - 手動承認の場合：承認者の確認待機

4. **ロールバック実行**
   - 指定スナップショットからの復元
   - 動作確認
   - ロールバック結果の通知

### 2. 自動ロールバック

#### 条件
- デプロイメント後のテスト失敗
- 本番環境での動作異常検知
- セキュリティ問題の検知

#### 実行フロー
1. 異常の検知
2. 自動バックアップ作成
3. 最新の正常スナップショットからの復元
4. 復元後の動作確認
5. 結果の通知

---

## ログとモニタリング

### 1. GitHub Actionsログ

#### ログの確認方法
1. GitHubリポジトリの **Actions** タブにアクセス
2. 実行履歴から該当のワークフローを選択
3. 各ジョブの詳細ログを確認

#### 重要なログ項目
- **認証情報**: AWS認証の成功/失敗
- **リソース操作**: EC2/RDSの起動/停止/復元
- **テスト結果**: 検証環境でのテスト結果
- **エラー情報**: 発生したエラーの詳細

### 2. AWS CloudWatchログ

#### 監視項目
- **EC2メトリクス**: CPU使用率、メモリ使用率、ディスク使用率
- **RDSメトリクス**: 接続数、クエリ実行時間、ストレージ使用率
- **ネットワーク**: トラフィック量、エラー率
- **セキュリティ**: セキュリティグループの変更、IAMアクセス

#### アラート設定
- **高負荷検知**: CPU使用率80%以上
- **ディスク容量不足**: 使用率90%以上
- **接続エラー**: 接続失敗率5%以上
- **セキュリティ違反**: 不正アクセスの検知

### 3. 通知設定

#### 通知方法
- **GitHub通知**: ワークフロー実行結果の通知
- **メール通知**: 重要なイベントのメール通知
- **Slack通知**: チームへの即座の通知

#### 通知内容
- **デプロイメント成功**: 正常完了の通知
- **デプロイメント失敗**: エラー詳細の通知
- **ロールバック実行**: ロールバック実行の通知
- **セキュリティ警告**: セキュリティ問題の通知

---

## セキュリティ考慮事項

### 1. 認証情報の管理

#### GitHub Secrets
- **機密情報**: AWS認証情報、SSH鍵、データベースパスワード
- **アクセス制御**: リポジトリ管理者のみアクセス可能
- **定期更新**: 認証情報の定期的な更新

#### 最小権限の原則
- **AWS IAM**: 必要最小限の権限のみ付与
- **SSHアクセス**: 特定IPからのアクセスのみ許可
- **データベース**: アプリケーションからのアクセスのみ許可

### 2. ネットワークセキュリティ

#### VPC設定
- **プライベートサブネット**: データベースの直接アクセス遮断
- **セキュリティグループ**: 必要最小限のポートのみ開放
- **NAT経由アクセス**: 検証環境への制限されたアクセス

#### 通信暗号化
- **HTTPS**: WordPressサイトの暗号化通信
- **SSH**: サーバーアクセスの暗号化
- **RDS**: データベース接続の暗号化

### 3. データ保護

#### バックアップ
- **自動バックアップ**: RDSの自動バックアップ
- **手動スナップショット**: デプロイメント前の手動バックアップ
- **バックアップ暗号化**: すべてのバックアップの暗号化

#### アクセス制御
- **WordPress管理**: 強力なパスワードと二要素認証
- **データベース**: アプリケーション専用ユーザー
- **ファイルシステム**: 適切なファイル権限設定

---

## トラブルシューティング

### 1. よくある問題と対処法

#### AWS認証エラー
```
Error: The security token included in the request is invalid
```
**対処法**:
1. GitHub SecretsのAWS認証情報を確認
2. AWS認証情報の有効性を確認
3. 必要に応じて新しい認証情報を生成

#### SSH接続エラー
```
Permission denied (publickey)
```
**対処法**:
1. GitHub SecretsのSSH秘密鍵を確認
2. SSH鍵の権限設定を確認
3. サーバーのSSH設定を確認

#### リソース見つからないエラー
```
Error: The specified DB instance does not exist
```
**対処法**:
1. GitHub Secretsのリソース識別子を確認
2. AWSリソースの存在確認
3. リージョンの設定確認

#### 承認エラー
```
Error: Approval required
```
**対処法**:
1. 承認者の設定確認
2. 承認シークレットの確認
3. 承認プロセスの確認

### 2. デバッグ方法

#### GitHub Actionsログの確認
1. ワークフローの実行履歴を確認
2. 各ステップの詳細ログを確認
3. エラーメッセージの詳細を確認

#### AWSリソースの確認
```bash
# EC2インスタンスの状態確認
aws ec2 describe-instances --instance-ids i-xxxxxxxxx

# RDSインスタンスの状態確認
aws rds describe-db-instances --db-instance-identifier wp-example-rds

# セキュリティグループの確認
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

#### 手動での接続テスト
```bash
# SSH接続テスト
ssh -i ~/.ssh/id_rsa ec2-user@[サーバーIP]

# データベース接続テスト
mysql -h [RDSエンドポイント] -u [ユーザー名] -p
```

### 3. 緊急時の対応

#### ワークフローの停止
1. GitHub Actionsで実行中のワークフローを停止
2. 手動での状態確認
3. 必要に応じて手動での復旧作業

#### 手動でのロールバック
1. 最新のスナップショットを確認
2. 手動での復元作業
3. 復元後の動作確認

---

## ベストプラクティス

### 1. デプロイメント前の準備

#### チェックリスト
- [ ] 本番環境のバックアップが作成されている
- [ ] 検証環境でのテストが完了している
- [ ] 承認者が設定されている
- [ ] 通知設定が有効になっている
- [ ] ロールバック手順が確認されている

#### テスト項目
- [ ] WordPressサイトの表示確認
- [ ] 管理画面へのログイン確認
- [ ] 新規投稿の作成確認
- [ ] コメント機能の確認
- [ ] 画像アップロードの確認

### 2. デプロイメント中の監視

#### 監視項目
- **ワークフロー実行**: GitHub Actionsの実行状況
- **リソース状態**: EC2/RDSの起動/停止状況
- **ネットワーク**: 接続状況とレスポンス時間
- **ログ**: エラーログと警告メッセージ

#### 対応手順
1. **正常時**: 完了通知の確認
2. **警告時**: ログの詳細確認
3. **エラー時**: 即座のロールバック検討

### 3. デプロイメント後の確認

#### 確認項目
- [ ] 本番環境の正常動作確認
- [ ] パフォーマンスの確認
- [ ] セキュリティログの確認
- [ ] バックアップの確認
- [ ] 検証環境のクリーンアップ確認

#### ドキュメント更新
- [ ] 変更内容の記録
- [ ] 設定変更の記録
- [ ] 問題と対処法の記録
- [ ] 次回の改善点の記録

### 4. 定期メンテナンス

#### 週次メンテナンス
- [ ] ログの確認と分析
- [ ] パフォーマンスの確認
- [ ] セキュリティの確認
- [ ] バックアップの確認

#### 月次メンテナンス
- [ ] 認証情報の更新
- [ ] セキュリティパッチの適用
- [ ] パフォーマンスの最適化
- [ ] コストの見直し

#### 四半期メンテナンス
- [ ] アーキテクチャの見直し
- [ ] セキュリティ監査の実施
- [ ] ドキュメントの更新
- [ ] ベストプラクティスの更新

---

## まとめ

この自動デプロイメントシステムにより、安全で効率的なWordPress環境の運用が可能になります。GitHub Actionsを活用することで、手動作業を最小限に抑え、人的ミスを削減できます。

### 重要なポイント
1. **安全性**: 検証環境でのテストと承認フロー
2. **効率性**: 自動化による作業時間の短縮
3. **可視性**: 詳細なログと監視機能
4. **保守性**: 標準化されたワークフロー

### 今後の改善
1. **監視強化**: より詳細な監視機能の追加
2. **自動化拡張**: より多くの作業の自動化
3. **セキュリティ強化**: より厳格なセキュリティ設定
4. **パフォーマンス最適化**: 実行時間の短縮

このシステムを活用して、安全で効率的なWordPress環境の運用を実現してください。 