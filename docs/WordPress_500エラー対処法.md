# WordPress 500エラー対処法

## 概要

WordPressで500エラー（Internal Server Error）が発生した場合の調査方法と対処法を説明します。

## 500エラーの主な原因

### 1. **データベース接続エラー**
- データベースサーバーが停止している
- データベース認証情報が間違っている
- データベースが存在しない

### 2. **PHP設定の問題**
- メモリ不足
- 実行時間制限
- PHP拡張モジュールの不足

### 3. **ファイル権限の問題**
- WordPressファイルの権限が不適切
- wp-config.phpの権限が厳しすぎる

### 4. **wp-config.phpの設定ミス**
- データベース設定が間違っている
- 認証キーが設定されていない

### 5. **Apache設定の問題**
- .htaccessファイルの設定ミス
- mod_rewriteが有効になっていない

## 調査手順

### ステップ1: デバッグモードの有効化

```bash
# デバッグプレイブックを実行
cd ansible
ansible-playbook -i inventory/ playbooks/wordpress_debug.yml
```

### ステップ2: ログファイルの確認

```bash
# WordPress デバッグログ
sudo tail -f /var/www/html/wp-content/debug.log

# Apache エラーログ
sudo tail -f /var/log/httpd/wordpress_error.log

# PHP エラーログ
sudo tail -f /var/log/php_errors.log
```

### ステップ3: 自動調査スクリプトの実行

```bash
# 調査スクリプトを実行
./scripts/wordpress_debug.sh [サーバーIP]
```

## 対処法

### 1. データベース接続エラーの対処

#### RDS接続確認
```bash
# RDSエンドポイントの確認
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,DBInstanceStatus]' --output table

# データベース接続テスト
mysql -h [RDS_ENDPOINT] -u [USERNAME] -p [DATABASE_NAME]
```

#### wp-config.phpの設定確認
```bash
# データベース設定の確認
sudo grep -E 'DB_(NAME|USER|PASSWORD|HOST)' /var/www/html/wp-config.php
```

### 2. PHP設定の調整

#### メモリ制限の増加
```ini
# /etc/php.ini
memory_limit = 512M
max_execution_time = 300
```

#### 必要なPHP拡張モジュールの確認
```bash
# インストール済みモジュールの確認
php -m | grep -E "(mysql|gd|mbstring|xml|curl|json|zip)"

# 不足しているモジュールのインストール
sudo dnf install php-mysqlnd php-gd php-mbstring php-xml php-curl php-json php-zip
```

### 3. ファイル権限の修正

```bash
# WordPressディレクトリの権限設定
sudo chown -R apache:apache /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod 644 /var/www/html/wp-config.php

# wp-contentディレクトリの権限設定
sudo chmod -R 775 /var/www/html/wp-content/
```

### 4. .htaccessファイルの確認

```bash
# .htaccessファイルのバックアップ
sudo cp /var/www/html/.htaccess /var/www/html/.htaccess.backup

# デフォルトの.htaccessファイルを作成
sudo cat > /var/www/html/.htaccess << 'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
```

### 5. Apache設定の確認

```bash
# mod_rewriteの有効化確認
sudo httpd -M | grep rewrite

# Apache設定の構文チェック
sudo httpd -t

# Apacheの再起動
sudo systemctl restart httpd
```

## よくあるエラーメッセージと対処法

### "Error establishing a database connection"
- データベースサーバーの状態確認
- 接続情報の確認
- セキュリティグループの設定確認

### "Allowed memory size exhausted"
- PHPメモリ制限の増加
- プラグインの無効化
- テーマの変更

### "Maximum execution time exceeded"
- PHP実行時間制限の増加
- プラグインの最適化
- データベースの最適化

### "Parse error: syntax error"
- プラグインやテーマのPHP構文エラー
- カスタムコードの確認

## 予防策

### 1. 定期的なバックアップ
```bash
# データベースバックアップ
mysqldump -h [RDS_ENDPOINT] -u [USERNAME] -p [DATABASE_NAME] > backup.sql

# ファイルバックアップ
sudo tar -czf wordpress_backup.tar.gz /var/www/html/
```

### 2. 監視の設定
- ログファイルの監視
- ディスク使用量の監視
- メモリ使用量の監視

### 3. セキュリティの強化
- 定期的なパスワード変更
- 不要なプラグインの削除
- セキュリティプラグインの導入

## トラブルシューティング後の作業

### デバッグモードの無効化
```bash
# デバッグを無効化
cd ansible
ansible-playbook -i inventory/ playbooks/wordpress_debug_disable.yml
```

### ログファイルのクリーンアップ
```bash
# 古いログファイルの削除
sudo find /var/log/ -name "*.log" -mtime +30 -delete
```

## 参考リンク

- [WordPress デバッグ](https://wordpress.org/support/article/debugging-in-wordpress/)
- [PHP エラーログ](https://www.php.net/manual/ja/errorfunc.configuration.php)
- [Apache エラーログ](https://httpd.apache.org/docs/2.4/logs.html)
