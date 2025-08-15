# Prepare Validation Environment Workflow

## 概要

このワークフローは、本番環境のスナップショットを作成し、検証環境を準備するためのGitHub Actionsワークフローです。元の`scripts/deployment/prepare_validation.sh`スクリプトを置き換えます。

## 機能

### 主要な処理

1. **設定ファイルの検証**
   - `deployment_config.json`の必須フィールドをチェック
   - JSON形式の妥当性を確認

2. **本番環境のスナップショット作成**
   - RDSスナップショットを作成
   - タイムスタンプ付きのスナップショットIDを生成

3. **検証環境の起動**
   - 検証用EC2インスタンスを起動
   - 検証用RDSインスタンスを起動（必要に応じてスナップショットから復元）

4. **準備完了待機**
   - EC2インスタンスの準備完了を待機
   - RDSインスタンスの準備完了を待機

5. **検証環境のテスト**
   - WordPressサイトの動作確認
   - 管理画面のアクセス確認
   - データベース接続の確認

## トリガー

### 自動実行
- `main`または`develop`ブランチへのプッシュ
- `scripts/deployment/prepare_validation.sh`または`deployment_config.json`の変更時

### 手動実行
- GitHub Actions UIからの手動実行
- 以下の入力パラメータを指定可能：
  - `environment`: 準備する環境（validation/staging）
  - `dry_run`: ドライランモード
  - `auto_approve`: 自動承認

## 必要な設定

### GitHub Secrets
- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー

### 設定ファイル
`deployment_config.json`に以下のフィールドが必要：

```json
{
  "production": {
    "ec2_instance_id": "i-xxxxxxxxx",
    "rds_identifier": "wordpress-project-rds"
  },
  "validation": {
    "ec2_instance_id": "i-xxxxxxxxx",
    "rds_identifier": "wordpress-project-rds-validation",
    "wordpress_url": "http://validation.example.com",
            "db_password": "your-secure-password-here"
  }
}
```

## ワークフローの流れ

### 1. validate-config
- 設定ファイルの存在確認
- 必須フィールドの検証
- JSON形式の妥当性チェック

### 2. prepare-validation
- AWS認証情報の設定
- 設定ファイルからの値読み込み
- 本番環境スナップショットの作成
- 検証環境の起動と準備
- 検証環境でのテスト実行

### 3. notify-completion
- 成功/失敗の通知
- Slack通知の準備（コメントアウト）

## エラーハンドリング

### 設定エラー
- 設定ファイルが見つからない場合
- 必須フィールドが不足している場合
- JSON形式が不正な場合

### AWS操作エラー
- RDSスナップショット作成失敗
- EC2/RDS起動失敗
- 接続テスト失敗

### タイムアウト
- WordPressサイトの準備完了待機（30回試行、10秒間隔）
- EC2/RDSの準備完了待機

## 出力情報

### 検証環境情報
- 検証環境IPアドレス
- 検証環境URL
- 管理画面URL
- スナップショットID

### ログ
- 各ステップの実行状況
- エラーメッセージ
- 成功メッセージ

## セキュリティ

### 認証情報
- AWS認証情報はGitHub Secretsで管理
- 環境変数での機密情報の取り扱い

### アクセス制御
- 検証環境へのアクセス制限
- データベース接続の認証

## トラブルシューティング

### よくある問題

1. **設定ファイルエラー**
   - `deployment_config.json`の形式を確認
   - 必須フィールドが設定されているか確認

2. **AWS認証エラー**
   - GitHub Secretsの設定を確認
   - AWS IAM権限を確認

3. **接続テスト失敗**
   - 検証環境のネットワーク設定を確認
   - セキュリティグループの設定を確認

4. **タイムアウトエラー**
   - 検証環境の起動時間を確認
   - リソースの状態を確認

### デバッグ方法

1. **ログの確認**
   - GitHub Actionsのログを詳細に確認
   - エラーメッセージの内容を確認

2. **手動確認**
   - AWSコンソールでリソースの状態を確認
   - 検証環境への直接アクセスを試行

3. **設定の再確認**
   - 設定ファイルの内容を再確認
   - AWS認証情報の有効性を確認

## 次のステップ

検証環境の準備が完了したら、以下のワークフローを使用できます：

1. **WordPress Deployment**: 本番環境へのデプロイ
2. **Rollback**: 問題発生時のロールバック

## 注意事項

- 検証環境の準備には時間がかかる場合があります
- スナップショット作成中は本番環境のパフォーマンスに影響する可能性があります
- 検証環境のテスト完了後は、本番環境へのデプロイを検討してください
