# SSL設定自動検証・修正システム

このドキュメントでは、Terraform実行時にSSL設定の問題を自動的に検出・修正するシステムについて説明します。

## 概要

SSL設定自動検証・修正システムは、以下の問題を自動的に検出・修正します：

1. **循環依存**: ACMとRoute53モジュールの相互依存
2. **重複レコード**: 古い検証レコードの残存
3. **ネームサーバー不一致**: ドメイン登録とRoute53ゾーンの設定の違い

## システム構成

### スクリプトファイル

| ファイル | 説明 |
|---------|------|
| `scripts/validate-ssl-setup.sh` | メインの検証・修正スクリプト |
| `scripts/pre-apply-validation.sh` | Terraform apply前の事前検証 |
| `.github/workflows/ssl-validation.yml` | GitHub Actions自動検証ワークフロー |

### 検証項目

#### 1. 循環依存の検出・修正

**検出方法**:
- Route53モジュールでACM検証レコードが作成されているかチェック
- ACMモジュールでDNS検証レコードが作成されているかチェック

**修正方法**:
- 古いRoute53検証レコードを削除
- ACMモジュールでDNS検証レコードを作成

#### 2. 重複レコードの検出・修正

**検出方法**:
- Route53で重複する検証レコードをチェック
- 同じ名前のCNAMEレコードが複数存在するか確認

**修正方法**:
- 古い検証レコードを削除
- ACMモジュールで管理されるレコードのみを残す

#### 3. ネームサーバー不一致の検出・修正

**検出方法**:
- 実際のネームサーバーとRoute53ゾーンのネームサーバーを比較
- `dig`コマンドで実際のネームサーバーを取得

**修正方法**:
- ドメイン登録のネームサーバーをRoute53ゾーンと同期
- AWS Route53 Domains APIを使用して自動更新

#### 4. DNS伝播の確認

**確認方法**:
- 検証レコードのDNS伝播状況をチェック
- `dig`コマンドで外部からのアクセス可能性を確認

#### 5. 証明書状態の確認

**確認方法**:
- ACM証明書の現在の状態を確認
- `PENDING_VALIDATION` → `ISSUED`の変更を監視

## 使用方法

### 手動実行

```bash
# プロジェクトルートで実行
./scripts/validate-ssl-setup.sh
```

### Terraform apply前の自動実行

```bash
# 事前検証を実行してからTerraform apply
./scripts/pre-apply-validation.sh && terraform apply
```

### GitHub Actionsでの自動実行

#### スケジュール実行
- **頻度**: 毎日午前9時（JST）
- **目的**: 定期的なSSL設定の健全性チェック

#### 手動実行
- **トリガー**: GitHub Actionsの手動実行
- **目的**: 必要に応じた即座の検証

#### 自動実行
- **トリガー**: ACM/Route53モジュールの変更時
- **目的**: 設定変更時の即座の検証

## ログとアーティファクト

### ログファイル
- **場所**: `ssl-validation.log`
- **内容**: 検証・修正の詳細ログ
- **形式**: 色付きの構造化ログ

### Terraform出力
- **場所**: `terraform_output.json`
- **内容**: 検証に必要なTerraform出力
- **用途**: スクリプト内での情報取得

### GitHub Actionsアーティファクト
- **名前**: `ssl-validation-logs`
- **保持期間**: 30日
- **内容**: ログファイルとTerraform出力

## エラーハンドリング

### 前提条件チェック
- AWS CLI、Terraform、dig、jqの存在確認
- 必要な権限の確認

### エラー時の対応
- 詳細なエラーメッセージの出力
- GitHub Issuesの自動作成
- ログファイルへの記録

### タイムアウト処理
- ネームサーバー更新の完了待機（最大5分）
- DNS伝播の待機（24-48時間の目安を表示）

## 設定例

### 基本的な使用方法

```bash
# 1. プロジェクトに移動
cd /path/to/aws-terraform

# 2. 検証・修正を実行
./scripts/validate-ssl-setup.sh

# 3. 結果を確認
cat ssl-validation.log
```

### CI/CDパイプラインでの統合

```yaml
# .github/workflows/example.yml
- name: SSL Validation
  run: |
    ./scripts/validate-ssl-setup.sh
    
- name: Terraform Apply
  run: |
    terraform apply -auto-approve
```

## トラブルシューティング

### よくある問題

#### 1. 権限エラー
```
Error: AccessDenied
```
**解決方法**: AWS認証情報とIAM権限を確認

#### 2. ネームサーバー更新の失敗
```
Error: Nameserver update failed
```
**解決方法**: Route53 Domains APIの権限を確認

#### 3. DNS伝播の遅延
```
Warning: DNS propagation pending
```
**解決方法**: 24-48時間待機（通常の動作）

### デバッグ方法

```bash
# 詳細ログの確認
tail -f ssl-validation.log

# Terraform状態の確認
terraform state list | grep route53
terraform state list | grep acm

# DNS伝播の手動確認
dig shamolife.com NS
dig _cacb619322fc2cb87a11be788dddbc78.shamolife.com CNAME
```

## セキュリティ考慮事項

### 最小権限の原則
- 必要なAWS権限のみを付与
- 読み取り専用権限の活用

### 認証情報の管理
- GitHub Secretsでの安全な管理
- 定期的な認証情報のローテーション

### ログの管理
- 機密情報のログ出力を避ける
- ログファイルの適切な保持期間設定

## 今後の改善

### 短期的改善
- より詳細なエラーメッセージ
- 複数ドメイン対応
- 並列処理による高速化

### 中期的改善
- 監視ダッシュボードの追加
- アラート機能の強化
- 自動修復機能の拡張

### 長期的改善
- AI/MLによる問題予測
- マルチリージョン対応
- サーバーレス化

## 結論

SSL設定自動検証・修正システムにより、以下の効果が期待できます：

### ✅ 達成される効果
- **自動化**: 手動作業の削減
- **安全性**: 設定ミスの防止
- **効率性**: 問題の早期発見・修正
- **信頼性**: 一貫した設定の維持

### 🎯 運用の改善
- **プロアクティブ**: 問題の事前検出
- **自動修復**: 設定の自動修正
- **可視性**: 詳細なログとレポート
- **継続性**: 定期的な健全性チェック

このシステムにより、SSL設定の管理がより安全で効率的になります。
