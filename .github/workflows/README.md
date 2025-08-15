# GitHub Actions WordPress Deployment Pipeline

このディレクトリには、WordPress自動デプロイメントスクリプトをGitHub Actionsに置き換えたワークフローファイルが含まれています。

## 概要

元の `scripts/deployment/auto_deployment.sh` スクリプトの機能をGitHub Actionsで実装し、以下の機能を提供します：

- 本番環境のスナップショット作成
- 検証環境の起動・復元
- 検証環境でのテスト実行
- 本番環境への反映
- 検証環境の停止
- ロールバック機能
- 通知機能

## ファイル構成

```
.github/workflows/
├── wordpress-deployment.yml    # メインのデプロイメントワークフロー
├── config/
│   └── deployment-config-template.json  # 設定ファイルテンプレート
└── scripts/
    └── deployment-helper.sh    # デプロイメントヘルパースクリプト
```

## 設定

### 1. GitHub Secrets の設定

以下のシークレットをGitHubリポジトリに設定してください：

- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー
- `SLACK_WEBHOOK_URL`: Slack通知用Webhook URL（オプション）

### 2. 環境設定

GitHubリポジトリの設定で以下の環境を作成してください：

- `validation`: 検証環境用
- `production`: 本番環境用

### 3. deployment_config.json の設定

```json
{
    "production": {
        "ec2_instance_id": "i-xxxxxxxxx",
        "rds_identifier": "wordpress-project-rds",
        "wordpress_url": "https://example.com"
    },
    "validation": {
        "ec2_instance_id": "i-yyyyyyyyy",
        "rds_identifier": "wordpress-project-rds-validation",
        "wordpress_url": "http://validation-ip"
    },
    "deployment": {
        "auto_approve": false,
        "rollback_on_failure": true
    }
}
```

## 使用方法

### 1. 手動実行

GitHub Actionsのページから手動でワークフローを実行できます：

1. GitHubリポジトリの「Actions」タブに移動
2. 「WordPress Deployment Pipeline」を選択
3. 「Run workflow」をクリック
4. 以下のパラメータを設定：
   - **Environment**: `validation` または `production`
   - **Dry Run Mode**: ドライラン実行（オプション）
   - **Auto Approve Deployment**: 自動承認（オプション）

### 2. 自動実行

以下の条件でワークフローが自動実行されます：

- `main`ブランチへのプッシュ
- 以下のファイルが変更された場合：
  - `scripts/**`
  - `ansible/**`
  - `terraform.tfvars`
  - `deployment_config.json`

### 3. プルリクエスト

プルリクエストでは検証環境のみが実行され、本番環境へのデプロイメントは手動承認が必要です。

## ワークフローの流れ

### 1. 設定検証 (validate-config)
- `deployment_config.json` の形式と必須項目を検証
- 設定が無効な場合は後続のジョブをスキップ

### 2. ドライラン (dry-run)
- 実際の変更を行わずに設定を表示
- デプロイメント前の確認用

### 3. 検証環境デプロイメント (validation-deployment)
- 本番環境のスナップショット作成
- 検証環境の起動・復元
- 検証環境でのテスト実行

### 4. 本番環境デプロイメント (production-deployment)
- 本番環境のバックアップ作成
- 本番環境への反映
- 本番環境の動作確認
- 検証環境の停止

### 5. ロールバック (rollback)
- デプロイメント失敗時の自動ロールバック
- 最新のスナップショットから復元

## エラーハンドリング

### 1. 設定エラー
- 設定ファイルの形式エラー
- 必須項目の欠落
- AWS認証情報の不備

### 2. AWS操作エラー
- EC2/RDSインスタンスの存在確認
- スナップショット作成・復元エラー
- インスタンス起動・停止エラー

### 3. 接続テストエラー
- 検証環境への接続失敗
- 本番環境への接続失敗
- タイムアウトエラー

### 4. ロールバック
- デプロイメント失敗時の自動ロールバック
- スナップショットからの復元

## 通知機能

### 1. Slack通知
- デプロイメント成功/失敗の通知
- 詳細情報（リポジトリ、ブランチ、コミット、実行者）

### 2. GitHub通知
- ワークフロー実行状況の通知
- プルリクエストでのコメント通知

## セキュリティ

### 1. 環境保護
- 本番環境へのデプロイメントには手動承認が必要
- 環境別の権限設定

### 2. 認証情報
- AWS認証情報はGitHub Secretsで管理
- 最小権限の原則に従ったIAMポリシー

### 3. ロールバック
- デプロイメント失敗時の自動ロールバック
- データの整合性保護

## トラブルシューティング

### 1. よくあるエラー

#### AWS認証情報エラー
```
Error: AWS認証情報が設定されていません
```
**解決方法**: GitHub SecretsにAWS認証情報を正しく設定してください。

#### 設定ファイルエラー
```
Error: 設定ファイルのJSON形式が無効です
```
**解決方法**: `deployment_config.json` のJSON形式を確認してください。

#### リソース存在エラー
```
Error: EC2インスタンスが見つかりません
```
**解決方法**: 設定ファイルのインスタンスIDを確認してください。

### 2. ログの確認

各ステップのログはGitHub Actionsの実行履歴で確認できます：

1. GitHubリポジトリの「Actions」タブに移動
2. 実行履歴を選択
3. 各ジョブのログを確認

### 3. 手動復旧

デプロイメントが失敗した場合：

1. AWSコンソールでリソースの状態を確認
2. 必要に応じて手動でロールバック
3. 設定ファイルの修正
4. ワークフローの再実行

## 元のスクリプトとの違い

### 1. 改善点
- **可視性**: GitHub Actionsのダッシュボードで実行状況を確認
- **履歴管理**: 実行履歴の永続化
- **並行実行**: 複数の環境での並行処理
- **通知機能**: Slack等での自動通知
- **環境保護**: 本番環境への手動承認

### 2. 制限事項
- **対話的入力**: 手動承認が必要な場合がある
- **ローカル実行**: ローカルでの直接実行は不可
- **ネットワーク依存**: GitHub Actionsの実行環境に依存

## 今後の拡張

### 1. 追加機能
- 複数環境への同時デプロイメント
- カスタムテストスクリプトの実行
- メトリクス収集と可視化
- 自動スケーリング対応

### 2. 最適化
- 並行処理の最適化
- キャッシュ機能の追加
- 実行時間の短縮

## サポート

問題や質問がある場合は、GitHub Issuesで報告してください。 