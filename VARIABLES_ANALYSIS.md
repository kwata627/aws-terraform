# プロジェクト変数分析レポート

このドキュメントは、aws-terraformプロジェクトで使用されているすべての変数を網羅的に分析した結果です。

## 【Terraformで使用している変数: このプロジェクトで入力された値】

### AWS設定
- **aws_region**: ap-northeast-1
- **aws_profile**: default

### プロジェクト設定
- **project**: wp-shamo
- **environment**: production

### ネットワーク設定
- **vpc_cidr**: 10.0.0.0/16
- **public_subnet_cidr**: 10.0.1.0/24
- **private_subnet_cidr**: 10.0.2.0/24
- **az1**: ap-northeast-1a

### EC2設定
- **ec2_name**: wp-shamo-ec2
- **validation_ec2_name**: wp-test-ec2
- **ami_id**: ami-095af7cb7ddb447ef
- **instance_type**: t2.micro
- **root_volume_size**: 8

### RDS設定
- **rds_identifier**: wp-shamo-rds
- **db_password**: breadhouse
- **snapshot_date**: (空)

### S3設定
- **s3_bucket_name**: wp-shamo-s3

### ドメイン設定
- **domain_name**: shamolife.com
- **register_domain**: false

### ドメイン登録者情報
- **registrant_info.first_name**: kazuki
- **registrant_info.last_name**: watanabe
- **registrant_info.organization_name**: Personal
- **registrant_info.email**: wata2watter0903@gmail.com
- **registrant_info.phone_number**: +81.80-4178-3008
- **registrant_info.address_line_1**: 2-17-11
- **registrant_info.city**: Niigata-shi, Chuo-ku
- **registrant_info.state**: Niigata
- **registrant_info.country_code**: JP
- **registrant_info.zip_code**: 9500915

### 検証環境設定
- **enable_validation_ec2**: true
- **enable_validation_rds**: false
- **validation_rds_snapshot_identifier**: (空)

### セキュリティ設定
- **ssh_allowed_cidr**: 0.0.0.0/0

### 追加タグ
- **tags.Owner**: watanabe
- **tags.Purpose**: wordpress-infrastructure
- **tags.CostCenter**: development
- **tags.Backup**: enabled
- **tags.Monitoring**: enabled

### SSL/TLS設定
- **enable_ssl_setup**: true
- **enable_lets_encrypt**: true
- **lets_encrypt_email**: wata2watter0903@gmail.com
- **lets_encrypt_staging**: false

### CloudFront設定
- **enable_cloudfront**: false

### その他の設定
- **ssh_key_name_suffix**: ssh-key (デフォルト値)
- **auto_update_nameservers**: true (デフォルト値)

## 【Ansibleで使用している変数/参照元】

### Terraformから自動生成される変数
- **domain_name**: shamolife.com (terraform.tfvarsから)
- **wordpress_domain**: domain_name (domain_nameを参照)
- **rds_endpoint**: wp-shamo-rds.cjg0emy2snss.ap-northeast-1.rds.amazonaws.com:3306 (Terraform出力から)
- **rds_host**: wp-shamo-rds.cjg0emy2snss.ap-northeast-1.rds.amazonaws.com (Terraform出力から)
- **rds_port**: 3306 (Terraform出力から)
- **s3_bucket_name**: wp-shamo-s3 (terraform.tfvarsから)
- **project_name**: wp-shamo (terraform.tfvarsから)
- **wordpress_url**: https://shamolife.com (domain_nameから生成)
- **wp_db_password**: breadhouse (terraform.tfvarsから)
- **wp_db_user**: admin (デフォルト値)
- **wp_db_name**: wordpress (デフォルト値)
- **enable_ssl_setup**: true (terraform.tfvarsから)
- **enable_lets_encrypt**: true (terraform.tfvarsから)
- **lets_encrypt_email**: wata2watter0903@gmail.com (terraform.tfvarsから)

### WordPressロールのデフォルト変数
- **wp_table_prefix**: wp_
- **wp_debug**: false
- **wp_lang**: ja
- **wordpress_locale**: ja
- **wordpress_language**: ja
- **wp_force_ssl_admin**: true
- **wp_force_ssl_login**: true
- **wp_cache_enabled**: false
- **wp_automatic_updater_disabled**: true
- **wp_disallow_file_edit**: true
- **wp_disallow_file_mods**: false
- **wp_memory_limit**: 256M
- **wp_max_memory_limit**: 512M
- **wp_post_revisions**: 5
- **wp_autosave_interval**: 300
- **wp_empty_trash_days**: 30
- **wp_htaccess_mode**: 0664
- **wp_htaccess_owner**: apache
- **wp_htaccess_group**: apache

### Apacheロールのデフォルト変数
- **apache_user**: apache
- **apache_group**: apache
- **document_root**: /var/www/html
- **apache_modules**: [rewrite, headers, ssl]

### PHPロールのデフォルト変数
- **php_memory_limit**: 256M
- **php_max_execution_time**: 300
- **php_max_input_time**: 300
- **php_post_max_size**: 64M
- **php_upload_max_filesize**: 64M
- **php_display_errors**: Off
- **php_log_errors**: On
- **php_session_gc_maxlifetime**: 1440
- **php_session_cookie_httponly**: 1
- **php_expose_php**: Off
- **php_allow_url_fopen**: Off
- **php_allow_url_include**: Off
- **php_opcache_enable**: 1
- **php_opcache_memory_consumption**: 128
- **php_opcache_interned_strings_buffer**: 8
- **php_opcache_max_accelerated_files**: 4000
- **php_opcache_revalidate_freq**: 2
- **php_opcache_fast_shutdown**: 1
- **php_date_timezone**: Asia/Tokyo
- **php_fpm_enabled**: true

### 環境変数から参照される変数
- **SSH_PRIVATE_KEY_PATH**: ~/.ssh/ssh_key (デフォルト値)
- **SSH_PUBLIC_KEY_PATH**: ~/.ssh/ssh_key.pub (デフォルト値)
- **WORDPRESS_DB_PASSWORD**: breadhouse (環境変数またはデフォルト値)

## 【それ以外/引数なしの変数】

### deployment_config.jsonの設定値
- **production.ec2_instance_id**: i-1234567890abcdef0
- **production.ec2_public_ip**: 54.64.49.220
- **production.nat_instance_ip**: 54.64.109.28
- **production.rds_identifier**: wp-shamo-rds
- **production.rds_endpoint**: wp-shamo-rds.cjg0emy2snss.ap-northeast-1.rds.amazonaws.com:3306
- **production.wordpress_url**: https://shamolife.com
- **production.db_password**: breadhouse
- **production.backup_retention_days**: 7
- **validation.ec2_instance_id**: i-0987654321fedcba0
- **validation.ec2_public_ip**: 203.0.113.20
- **validation.nat_instance_ip**: 203.0.113.21
- **validation.rds_identifier**: wp-shamo-rds-validation
- **validation.rds_endpoint**: wp-shamo-rds-validation.cjg0emy2snss.ap-northeast-1.rds.amazonaws.com:3306
- **validation.wordpress_url**: http://validation-ip
- **validation.db_password**: test_validation_password
- **validation.test_timeout_minutes**: 30
- **deployment.auto_approve**: false
- **deployment.rollback_on_failure**: true
- **deployment.notification_email**: admin@example.com

### locals.tfで定義されるローカル変数
- **common_tags**: Project, Environment, ManagedBy, Version + カスタムタグ
- **environment_config**: name, region, profile
- **resource_names**: 自動生成されるリソース名
- **network_config**: VPC、サブネット設定
- **security_rules**: セキュリティルール設定
- **ec2_config**: EC2設定
- **rds_config**: RDS設定
- **s3_config**: S3設定
- **domain_config**: ドメイン設定
- **security_features**: セキュリティ機能設定
- **network_features**: ネットワーク機能設定
- **rds_features**: RDS機能設定
- **s3_features**: S3機能設定
- **route53_features**: Route53機能設定

### 重複値を持つ変数（色字で表示）

<span style="color: red;">**domain_name**: shamolife.com (Terraform変数)</span>
<span style="color: red;">**wordpress_domain**: shamolife.com (Ansible変数、domain_nameを参照)</span>

<span style="color: red;">**db_password**: breadhouse (Terraform変数)</span>
<span style="color: red;">**wp_db_password**: breadhouse (Ansible変数、db_passwordを参照)</span>

<span style="color: red;">**lets_encrypt_email**: wata2watter0903@gmail.com (Terraform変数)</span>
<span style="color: red;">**lets_encrypt_email**: wata2watter0903@gmail.com (Ansible変数、Terraformから取得)</span>

<span style="color: red;">**rds_identifier**: wp-shamo-rds (Terraform変数)</span>
<span style="color: red;">**rds_identifier**: wp-shamo-rds (deployment_config.json)</span>

<span style="color: red;">**s3_bucket_name**: wp-shamo-s3 (Terraform変数)</span>
<span style="color: red;">**s3_bucket_name**: wp-shamo-s3 (Ansible変数、Terraformから取得)</span>

<span style="color: red;">**project**: wp-shamo (Terraform変数)</span>
<span style="color: red;">**project_name**: wp-shamo (Ansible変数、projectを参照)</span>

## 注意事項

1. **セキュリティ**: パスワードや秘密鍵などの機密情報は適切に管理されています
2. **重複値**: 同じ値を持つ変数は色字で表示されています
3. **デフォルト値**: 多くの変数はデフォルト値が設定されており、必要に応じてカスタマイズ可能です
4. **環境変数**: 一部の変数は環境変数から参照されており、セキュリティを向上させています
5. **自動生成**: リソース名の多くは自動生成されるため、一貫性が保たれています
