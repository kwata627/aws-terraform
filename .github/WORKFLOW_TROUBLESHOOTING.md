# GitHub Actionsワークフロー トラブルシューティングガイド

このドキュメントでは、GitHub Actionsワークフローのエラーを確認・修正する方法を説明します。

## エラー確認方法

### 1. 自動検証スクリプトの使用

```bash
# ワークフローの構文を自動検証
.github/scripts/validate-workflows.sh
```

このスクリプトは以下をチェックします：
- YAML構文エラー
- 必須フィールドの存在
- アクションのバージョン
- シークレット参照の確認

### 2. GitHub Actions UIでの確認

1. GitHubリポジトリの **Actions** タブにアクセス
2. ワークフローを選択
3. **Run workflow** をクリック
4. 実行結果を確認

### 3. ローカルでのYAML検証

```bash
# yamllintのインストール（推奨）
pip install yamllint

# ワークフローファイルの検証
yamllint .github/workflows/
```

## よくあるエラーと対処法

### 1. YAML構文エラー

#### エラー例
```yaml
# エラー: インデントが正しくない
jobs:
  deploy:
    runs-on: ubuntu-latest
  steps:  # インデントが浅すぎる
    - name: Checkout
```

#### 修正方法
```yaml
# 正しいインデント
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:  # 正しいインデント
      - name: Checkout
```

### 2. シークレット参照エラー

#### エラー例
```
Error: Required secret 'AWS_ACCESS_KEY_ID' not found
```

#### 対処法
1. GitHubリポジトリの **Settings** → **Secrets and variables** → **Actions**
2. 必要なシークレットを追加
3. シークレット名のスペルを確認

### 3. アクションのバージョンエラー

#### エラー例
```
Error: Action 'actions/checkout@v3' is deprecated
```

#### 対処法
```yaml
# 古いバージョン
- uses: actions/checkout@v3

# 新しいバージョン
- uses: actions/checkout@v4
```

### 4. 条件式の構文エラー

#### エラー例
```yaml
# エラー: 条件式が正しくない
if: ${{ github.event.inputs.dry_run == true }}
```

#### 修正方法
```yaml
# 正しい条件式
if: ${{ github.event.inputs.dry_run == 'true' }}
```

### 5. ファイル存在チェックエラー

#### エラー例
```
Error: File 'generate_inventory.py' not found
```

#### 対処法
```bash
# ファイルの存在確認を追加
if [ -f "generate_inventory.py" ]; then
  python3 generate_inventory.py
else
  echo "Warning: generate_inventory.py not found"
fi
```

## ワークフロー別の確認ポイント

### WordPress Setup ワークフロー

#### 確認項目
- [ ] `generate_inventory.py` が存在する
- [ ] `inventory/hosts.yml` が生成される
- [ ] SSH鍵が正しく設定されている
- [ ] WordPressサーバーにアクセス可能

#### よくある問題
```bash
# 問題: インベントリファイルが見つからない
Error: inventory/hosts.yml not found

# 解決: ファイル存在チェックを追加
if [ -f "inventory/hosts.yml" ]; then
  ansible-inventory --list -i inventory/hosts.yml
fi
```

### Auto Deployment ワークフロー

#### 確認項目
- [ ] AWS認証情報が正しく設定されている
- [ ] EC2/RDSインスタンスIDが正しい
- [ ] スナップショット作成権限がある
- [ ] 検証環境のリソースが利用可能

#### よくある問題
```bash
# 問題: AWSリソースが見つからない
Error: The specified DB instance does not exist

# 解決: リソース存在チェックを追加
if [ -n "${{ secrets.PRODUCTION_RDS_ID }}" ]; then
  aws rds describe-db-instances --db-instance-identifier ${{ secrets.PRODUCTION_RDS_ID }}
fi
```

### Rollback ワークフロー

#### 確認項目
- [ ] スナップショットが利用可能
- [ ] 本番環境が停止可能
- [ ] バックアップ作成権限がある
- [ ] 復元後のテストが可能

#### よくある問題
```bash
# 問題: スナップショットが見つからない
Error: Snapshot not found

# 解決: スナップショット存在チェックを追加
if [ -n "${{ steps.get_snapshot.outputs.snapshot_id }}" ]; then
  aws rds describe-db-snapshots --db-snapshot-identifier ${{ steps.get_snapshot.outputs.snapshot_id }}
fi
```

## デバッグ方法

### 1. ワークフローの手動実行

```bash
# GitHub CLIを使用した手動実行
gh workflow run wordpress-setup.yml
gh workflow run auto-deployment.yml
gh workflow run rollback.yml
```

### 2. ログの詳細確認

```bash
# 最新の実行ログを確認
gh run list --limit 5
gh run view <run-id> --log
```

### 3. 環境変数の確認

```yaml
# デバッグ用の環境変数出力
- name: Debug environment
  run: |
    echo "Event name: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
```

### 4. 条件式のデバッグ

```yaml
# 条件式の結果を確認
- name: Debug conditions
  run: |
    echo "Auto approve: ${{ github.event.inputs.auto_approve }}"
    echo "Dry run: ${{ github.event.inputs.dry_run }}"
    echo "Environment: ${{ github.event.inputs.environment }}"
```

## セキュリティチェック

### 1. シークレットの漏洩確認

```bash
# シークレットがログに出力されていないか確認
grep -r "AWS_ACCESS_KEY\|AWS_SECRET_ACCESS_KEY" .github/workflows/
```

### 2. 権限の最小化

```yaml
# 必要最小限の権限のみ付与
permissions:
  contents: read
  actions: read
```

### 3. 承認フローの確認

```yaml
# 手動承認の設定
- name: Manual approval
  uses: trstringer/manual-approval@v1
  with:
    secret: ${{ secrets.APPROVAL_SECRET }}
    approvers: ${{ secrets.APPROVERS }}
```

## パフォーマンス最適化

### 1. キャッシュの活用

```yaml
# Python依存関係のキャッシュ
- name: Cache pip dependencies
  uses: actions/cache@v3
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
```

### 2. 並列実行の活用

```yaml
# 独立したジョブの並列実行
jobs:
  test:
    runs-on: ubuntu-latest
  deploy:
    needs: test
    runs-on: ubuntu-latest
```

### 3. タイムアウトの設定

```yaml
# 長時間実行されるジョブのタイムアウト設定
jobs:
  deploy:
    timeout-minutes: 30
    runs-on: ubuntu-latest
```

## 定期メンテナンス

### 1. 週次チェック
- [ ] ワークフローの実行状況確認
- [ ] エラーログの確認
- [ ] シークレットの有効性確認

### 2. 月次チェック
- [ ] アクションのバージョン更新
- [ ] セキュリティ設定の確認
- [ ] パフォーマンスの最適化

### 3. 四半期チェック
- [ ] ワークフローの見直し
- [ ] 新しい機能の追加検討
- [ ] ドキュメントの更新

## 緊急時の対応

### 1. ワークフローの無効化

```bash
# 緊急時にワークフローを無効化
mv .github/workflows/auto-deployment.yml .github/workflows/auto-deployment.yml.disabled
```

### 2. 手動での復旧

```bash
# 手動でのデプロイメント実行
./scripts/deployment/auto_deployment.sh
```

### 3. ロールバックの実行

```bash
# 手動でのロールバック実行
./scripts/maintenance/rollback.sh
```

## サポート情報

### 1. ログの収集

```bash
# ワークフロー実行ログの収集
gh run list --limit 10 --json databaseId,status,conclusion,createdAt > workflow-logs.json
```

### 2. 設定の確認

```bash
# 現在の設定を確認
gh repo view --json name,defaultBranchRef
```

### 3. 問題の報告

問題が発生した場合は、以下を含めて報告してください：
- エラーメッセージの全文
- 実行環境の情報
- 再現手順
- 期待される動作 