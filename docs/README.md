# ドキュメント

このディレクトリには、WordPress環境の運用に関するドキュメントが含まれています。

## ドキュメント一覧

### 📋 運用手順書
- **[WordPress運用手順書_統合版.md](./WordPress運用手順書_統合版.md)** - WordPress環境の日常運用に関する手順書
- **[検証環境運用ガイド_統合版.md](./検証環境運用ガイド_統合版.md)** - 検証環境の運用に関するガイド

### 🚀 デプロイメント手順書
- **[WordPress自動デプロイメント手順書_統合版.md](./WordPress自動デプロイメント手順書_統合版.md)** - 自動デプロイメントシステムの使用方法

## GitHub Actionsワークフロー

GitHub Actionsワークフローの詳細については、`.github/workflows/`ディレクトリ内のREADMEファイルを参照してください：

- [GitHub Actionsワークフロー概要](../.github/workflows/README.md)
- [本番デプロイメントワークフロー](../.github/workflows/README-deploy-to-production.md)
- [ロールバックワークフロー](../.github/workflows/README-rollback.md)
- [検証環境準備ワークフロー](../.github/workflows/README-prepare-validation.md)
- [Terraform設定ワークフロー](../.github/workflows/README-terraform-config.md)

## 移行状況

スクリプトからGitHub Actionsへの移行状況については、以下を参照してください：

- [移行状況](../.github/MIGRATION_STATUS.md)
- [移行機能確認レポート](../.github/MIGRATION_VERIFICATION_REPORT.md)
- [GitHub Secrets設定ガイド](../.github/GITHUB_SECRETS_SETUP.md)
- [トラブルシューティングガイド](../.github/WORKFLOW_TROUBLESHOOTING.md)

## 使用方法

1. 初回セットアップ時は、[WordPress自動デプロイメント手順書](./WordPress自動デプロイメント手順書_統合版.md)を参照
2. 日常運用時は、[WordPress運用手順書](./WordPress運用手順書_統合版.md)を参照
3. 検証環境の運用時は、[検証環境運用ガイド](./検証環境運用ガイド_統合版.md)を参照

## 注意事項

- 本番環境での操作は慎重に行ってください
- デプロイメント前に必ず検証環境でテストを完了してください
- バックアップは定期的に確認してください
- セキュリティ設定は定期的に見直してください
