# Ansible Workflows

## 概要

このディレクトリには、AnsibleスクリプトをGitHub Actionsワークフローに置き換えたファイルが含まれています。元のAnsibleスクリプトの機能を自動化し、可視性とセキュリティを向上させています。

## ワークフロー一覧

### 1. Ansible WordPress Environment Setup
**ファイル**: `ansible-wordpress-setup.yml`

WordPress環境の構築を実行するメインワークフローです。元の`run_wordpress_setup.sh`スクリプトを置き換えます。

#### 機能
- インベントリの自動生成
- 接続テスト
- プレイブック実行（通常/ドライラン/段階的）
- 環境テスト
- 手動承認機能

#### トリガー
- `ansible/**`または`deployment_config.json`の変更時
- 手動実行（GitHub Actions UI）

#### 入力パラメータ
- `environment`: ターゲット環境（production/development/validation）
- `playbook`: 実行するプレイブック
- `dry_run`: ドライランモード
- `step_by_step`: 段階的実行
- `auto_approve`: 自動承認

### 2. Ansible Environment Test
**ファイル**: `ansible-environment-test.yml`

環境の動作確認を実行するワークフローです。元の`test_environment.sh`スクリプトを置き換えます。

#### 機能
- サーバー接続テスト
- システム情報取得
- サービス状態確認
- ファイル存在確認
- ポート接続確認
- WordPressアクセステスト
- データベース接続テスト

#### トリガー
- `ansible/**`または`deployment_config.json`の変更時
- 手動実行

### 3. Ansible Monitoring Test
**ファイル**: `ansible-monitoring-test.yml`

監視機能のテストを実行するワークフローです。元の`test_monitoring.sh`スクリプトを置き換えます。

#### 機能
- 監視プレイブックのテスト実行
- 監視スクリプトの存在確認
- ログディレクトリの確認
- 監視スクリプトの手動実行テスト
- ログファイルの確認
- システムリソースの確認

#### トリガー
- `ansible/**`または`deployment_config.json`の変更時
- 手動実行

## 必要な設定

### GitHub Secrets
- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー
- `SSH_PRIVATE_KEY`: SSH秘密鍵（EC2接続用）

### 設定ファイル
- `deployment_config.json`: デプロイメント設定
- `ansible/group_vars/`: Ansible変数ファイル
- `ansible/environments/`: 環境別設定ファイル

## ワークフローの流れ

### WordPress Environment Setup
1. **validate-config**: 設定ファイルの検証
2. **setup-ansible**: Ansible環境のセットアップ
3. **test-connections**: 接続テスト
4. **execute-playbook**: プレイブック実行
5. **test-environment**: 環境テスト
6. **notify-completion**: 完了通知

### Environment Test
1. **setup-ansible**: Ansible環境のセットアップ
2. **test-environment**: 環境テスト
3. **notify-completion**: 完了通知

### Monitoring Test
1. **setup-ansible**: Ansible環境のセットアップ
2. **test-monitoring**: 監視テスト
3. **notify-completion**: 完了通知

## セキュリティ機能

### 手動承認
- 本番環境への変更には手動承認が必要
- GitHub Actions UIで承認を実行
- `auto_approve`設定で自動承認も可能

### SSH認証
- SSH秘密鍵を使用したEC2接続
- GitHub Secretsで秘密鍵を管理

### 環境変数
- 機密情報はGitHub Secretsで管理
- 環境別の設定ファイルを使用

## エラーハンドリング

### 接続エラー
- リトライループで接続テスト
- タイムアウト設定
- 詳細なエラーメッセージ

### 設定エラー
- 設定ファイルの存在確認
- 必須フィールドの検証
- JSON/YAML形式の妥当性チェック

### 実行エラー
- プレイブック実行の失敗検出
- 環境テストの失敗検出
- 通知機能

## 出力情報

### ログ
- 各ステップの実行状況
- エラーメッセージ
- 成功メッセージ

### テスト結果
- 接続テスト結果
- 環境テスト結果
- 監視テスト結果

## トラブルシューティング

### よくある問題

1. **接続エラー**
   - SSH秘密鍵の設定を確認
   - EC2インスタンスの状態を確認
   - セキュリティグループの設定を確認

2. **インベントリ生成エラー**
   - AWS認証情報を確認
   - Terraformの状態を確認
   - 設定ファイルの形式を確認

3. **プレイブック実行エラー**
   - 変数ファイルの設定を確認
   - 環境設定ファイルの確認
   - ターゲットサーバーの状態を確認

### デバッグ方法

1. **ログの確認**
   - GitHub Actionsのログを詳細に確認
   - エラーメッセージの内容を確認

2. **手動確認**
   - AWSコンソールでリソースの状態を確認
   - ターゲットサーバーへの直接アクセスを試行

3. **段階的実行**
   - ドライランモードで実行
   - 段階的実行で問題箇所を特定

## 次のステップ

Ansibleワークフローの実行が完了したら、以下のワークフローを使用できます：

1. **WordPress Deployment**: 本番環境へのデプロイ
2. **Environment Test**: 環境の動作確認
3. **Monitoring Test**: 監視機能の確認

## 注意事項

- Ansibleワークフローは本番環境に影響を与える可能性があります
- 実行前に必ずドライランでテストしてください
- 手動承認が必要な場合は、慎重に実行してください
- 環境別の設定ファイルを適切に管理してください
