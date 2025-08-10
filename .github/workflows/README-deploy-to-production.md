# Deploy to Production Workflow

## 概要

このワークフローは、検証環境から本番環境へのデプロイメントを実行するGitHub Actionsワークフローです。元の`scripts/deployment/deploy_to_production.sh`スクリプトを置き換えます。

## 機能

### 主要な処理

1. **設定ファイルの検証**
   - `deployment_config.json`の必須フィールドをチェック
   - JSON形式の妥当性を確認

2. **検証環境の状態確認**
   - 検証環境が起動しているかチェック
   - デプロイメントの前提条件を確認

3. **本番環境のバックアップ作成**
   - データベースのバックアップ
   - WordPressファイルのバックアップ

4. **検証環境から本番環境への同期**
   - データベースの同期
   - WordPressファイルの同期

5. **本番環境の動作確認**
   - サイトの動作確認
   - 管理画面のアクセス確認

6. **検証環境の停止**
   - コスト削減のため検証環境を停止

## トリガー

### 自動実行
- `main`ブランチへのプッシュ
- `scripts/deployment/deploy_to_production.sh`または`deployment_config.json`の変更時

### 手動実行
- GitHub Actions UIからの手動実行
- 以下の入力パラメータを指定可能：
  - `environment`: ターゲット環境（production/staging）
  - `dry_run`: ドライランモード
  - `auto_approve`: 自動承認

## 必要な設定

### GitHub Secrets
- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー
- `SSH_PRIVATE_KEY`: SSH秘密鍵（EC2接続用）

### 設定ファイル
`deployment_config.json`に以下のフィールドが必要：

```json
{
  "production": {
    "ec2_instance_id": "i-xxxxxxxxx",
    "rds_identifier": "wp-shamo-rds",
    "wordpress_url": "https://example.com",
    "db_password": "password"
  },
  "validation": {
    "ec2_instance_id": "i-xxxxxxxxx",
    "rds_identifier": "wp-shamo-rds-validation",
    "db_password": "password"
  },
  "deployment": {
    "auto_approve": "false",
    "notification_email": "admin@example.com"
  }
}
```

## ワークフローの流れ

### 1. validate-config
- 設定ファイルの存在確認
- 必須フィールドの検証
- JSON形式の妥当性チェック

### 2. check-validation-environment
- AWS認証情報の設定
- 検証環境の起動状態を確認
- デプロイメントの前提条件をチェック

### 3. deploy-production
- AWS認証情報の設定
- 設定ファイルからの値読み込み
- 手動承認（auto_approveがfalseの場合）
- 本番環境のバックアップ作成
- 検証環境から本番環境への同期
- 本番環境の動作確認
- 検証環境の停止
- 一時ファイルのクリーンアップ

### 4. notify-completion
- 成功/失敗の通知
- Slack通知の準備（コメントアウト）

## セキュリティ機能

### 手動承認
- 本番環境へのデプロイメントには手動承認が必要
- GitHub Actions UIで承認を実行
- `auto_approve`設定で自動承認も可能

### バックアップ
- デプロイメント前に本番環境のバックアップを作成
- データベースとWordPressファイルの両方をバックアップ
- 問題発生時の復旧に使用

### SSH認証
- SSH秘密鍵を使用したEC2接続
- GitHub Secretsで秘密鍵を管理

## エラーハンドリング

### 設定エラー
- 設定ファイルが見つからない場合
- 必須フィールドが不足している場合
- JSON形式が不正な場合

### 前提条件エラー
- 検証環境が起動していない場合
- AWS認証情報が無効な場合

### 同期エラー
- データベース同期失敗
- ファイル同期失敗
- 接続テスト失敗

### タイムアウト
- 本番環境の準備完了待機（10回試行、10秒間隔）

## 出力情報

### デプロイメント情報
- 本番環境URL
- 管理画面URL
- バックアップファイル名

### ログ
- 各ステップの実行状況
- エラーメッセージ
- 成功メッセージ

## コスト最適化

### 検証環境の停止
- デプロイメント完了後に検証環境を自動停止
- コスト削減のため

### 一時ファイルのクリーンアップ
- デプロイメント後に一時ファイルを削除
- ストレージコストの削減

## トラブルシューティング

### よくある問題

1. **検証環境が起動していない**
   - `prepare-validation`ワークフローを先に実行
   - 検証環境の状態を確認

2. **SSH接続エラー**
   - SSH秘密鍵の設定を確認
   - EC2インスタンスのセキュリティグループを確認

3. **データベース同期エラー**
   - RDSインスタンスの状態を確認
   - データベースパスワードを確認

4. **ファイル同期エラー**
   - EC2インスタンスのディスク容量を確認
   - ファイル権限を確認

### デバッグ方法

1. **ログの確認**
   - GitHub Actionsのログを詳細に確認
   - エラーメッセージの内容を確認

2. **手動確認**
   - AWSコンソールでリソースの状態を確認
   - 本番環境への直接アクセスを試行

3. **バックアップからの復旧**
   - 作成されたバックアップファイルを使用
   - 手動でデータを復元

## 次のステップ

デプロイメントが失敗した場合、以下のワークフローを使用できます：

1. **Rollback**: 前のバージョンへのロールバック
2. **Prepare Validation**: 検証環境の再準備

## 注意事項

- 本番環境へのデプロイメントは慎重に実行してください
- デプロイメント前に必ず検証環境でテストを完了してください
- バックアップファイルは安全な場所に保管してください
- 検証環境の停止によりコストが削減されますが、再起動が必要です
