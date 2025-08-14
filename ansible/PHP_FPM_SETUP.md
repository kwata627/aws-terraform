# PHP-FPM設定修正ドキュメント

## 概要
今回の修正により、AnsibleでWordPress環境を構築する際に、PHP-FPMが正しく動作するように設定を変更しました。

## 修正内容

### 1. PHPロールの修正 (`ansible/roles/php/tasks/main.yml`)
- `php8.4-modphp`パッケージを`php8.4-fpm`に変更
- PHP-FPMの設定変更時にハンドラーを呼び出すように修正

### 2. PHP-FPM設定の有効化 (`ansible/roles/php/defaults/main.yml`)
- `php_fpm_enabled: true`に変更

### 3. PHP-FPM設定テンプレートの追加 (`ansible/roles/php/templates/www.conf.j2`)
- PHP-FPMの設定ファイルテンプレートを新規作成
- 適切なパフォーマンス設定とセキュリティ設定を含む

### 4. Apacheロールの修正 (`ansible/roles/apache/tasks/main.yml`)
- mod_php設定ファイルの無効化処理を追加
- mod_proxy_fcgiモジュールの有効化確認を追加

### 5. Apache設定テンプレートの修正 (`ansible/roles/apache/templates/wordpress.conf.j2`)
- ServerNameをWordPressドメインに設定
- ServerAliasをEC2インスタンスのIPアドレスに設定

### 6. デフォルト変数の修正
- Apacheロール: `wordpress_domain: example.com`に設定
- プレイブック: 環境変数からWordPressドメインを取得するように修正

### 7. ハンドラーの追加 (`ansible/roles/php/handlers/main.yml`)
- PHP-FPMの再起動とリロード用ハンドラーを新規作成

## 設定の流れ

1. **mod_phpの無効化**: `20-php.conf`を削除してmod_phpを無効化
2. **PHP-FPMのインストール**: `php8.4-fpm`パッケージをインストール
3. **PHP-FPMの設定**: 適切な設定ファイルを配置
4. **Apacheの設定**: CloudFrontからのアクセスを正しく処理
5. **サービスの起動**: PHP-FPMとApacheを起動

## 環境変数

以下の環境変数を設定することで、WordPressドメインをカスタマイズできます：

```bash
export WORDPRESS_DOMAIN="example.com"
```

## 注意事項

- 既存のmod_php設定は`20-php.conf.backup`としてバックアップされます
- PHP-FPMは`/run/php-fpm/www.sock`でApacheと通信します
- CloudFrontからのアクセスは`example.com`のHostヘッダーで処理されます

## トラブルシューティング

### PHP-FPMが起動しない場合
```bash
sudo systemctl status php-fpm
sudo journalctl -u php-fpm -f
```

### ApacheがPHPファイルを処理しない場合
```bash
sudo systemctl status httpd
sudo tail -f /var/log/httpd/wordpress_error.log
```

### 設定ファイルの確認
```bash
# PHP-FPM設定
sudo cat /etc/php-fpm.d/www.conf

# Apache設定
sudo cat /etc/httpd/conf.d/wordpress.conf

# mod_phpが無効化されているか確認
ls -la /etc/httpd/conf.modules.d/20-php.conf*
```
