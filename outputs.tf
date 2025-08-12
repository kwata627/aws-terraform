# =============================================================================
# Main Terraform Outputs (Refactored)
# =============================================================================
# 
# このファイルはメインTerraform設定の出力定義を含みます。
# セキュアなインフラ設定とセキュリティ機能に対応しています。
# =============================================================================

# -----------------------------------------------------------------------------
# Domain Analysis Outputs
# -----------------------------------------------------------------------------

output "domain_analysis" {
  description = "ドメイン分析結果"
  value = {
    domain_name = local.domain_config.domain_name
    should_use_existing_zone = local.should_use_existing_zone
    should_register_domain = local.should_register_domain
    domain_exists_in_route53 = local.domain_exists_in_route53
    domain_exists_in_dns = local.domain_exists_in_dns
    domain_registered = local.domain_registered
  }
}

# -----------------------------------------------------------------------------
# SSH Key Auto-Setup Resource
# -----------------------------------------------------------------------------

resource "null_resource" "ssh_key_setup" {
  triggers = {
    ssh_private_key = module.ssh.private_key_pem
    wordpress_public_ip = module.ec2.public_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      # SSH鍵を保存
      echo '${module.ssh.private_key_pem}' > ~/.ssh/wordpress_key
      chmod 600 ~/.ssh/wordpress_key
      
      # SSH設定ファイルに追加（既存の設定をチェック）
      if ! grep -q "Host wordpress-server" ~/.ssh/config 2>/dev/null; then
        echo "" >> ~/.ssh/config
        echo "Host wordpress-server" >> ~/.ssh/config
        echo "  HostName ${module.ec2.public_ip}" >> ~/.ssh/config
        echo "  User ec2-user" >> ~/.ssh/config
        echo "  IdentityFile ~/.ssh/wordpress_key" >> ~/.ssh/config
        echo "  StrictHostKeyChecking no" >> ~/.ssh/config
        echo "  UserKnownHostsFile /dev/null" >> ~/.ssh/config
      else
        # 既存の設定を更新
        sed -i "s|HostName.*|HostName ${module.ec2.public_ip}|" ~/.ssh/config
      fi
      
      echo "SSH鍵の設定が完了しました:"
      echo "- 秘密鍵: ~/.ssh/wordpress_key"
      echo "- SSH設定: ~/.ssh/config"
      echo "- 接続コマンド: ssh wordpress-server"
    EOT
  }

  depends_on = [module.ec2, module.ssh]
}

# -----------------------------------------------------------------------------
# Ansible Auto-Setup Resource
# -----------------------------------------------------------------------------

resource "null_resource" "ansible_setup" {
  triggers = {
    wordpress_public_ip = module.ec2.public_ip
    ssh_private_key = module.ssh.private_key_pem
    domain_name = var.domain_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Ansibleディレクトリに移動
      cd ansible
      
      # インベントリ生成スクリプトの実行
      echo "Ansibleインベントリを生成中..."
      python3 generate_inventory.py
      
      # 生成されたインベントリの確認
      if [ -f "inventory/hosts.yml" ]; then
        echo "✓ インベントリファイルが生成されました: inventory/hosts.yml"
        echo ""
        echo "インベントリ内容:"
        cat inventory/hosts.yml
      else
        echo "✗ インベントリファイルの生成に失敗しました"
        exit 1
      fi
      
      # Ansible設定の確認
      echo ""
      echo "Ansible設定を確認中..."
      if command -v ansible-inventory &> /dev/null; then
        ansible-inventory --list -i inventory/hosts.yml
        echo "✓ Ansible設定が正常です"
      else
        echo "警告: ansible-inventoryコマンドが見つかりません"
      fi
      
      # 元のディレクトリに戻る
      cd ..
      
      echo ""
      echo "Ansible設定が完了しました！"
      echo "次のステップ:"
      echo "  cd ansible"
      echo "  ansible-playbook -i inventory/hosts.yml playbooks/wordpress-setup.yml"
    EOT
  }

  depends_on = [module.ec2, module.ssh, null_resource.ssh_key_setup]
}

# -----------------------------------------------------------------------------
# WordPress Environment Setup Resource
# -----------------------------------------------------------------------------

resource "null_resource" "wordpress_setup" {
  triggers = {
    wordpress_public_ip = module.ec2.public_ip
    ssh_private_key = module.ssh.private_key_pem
    rds_endpoint = module.rds.db_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      # 環境変数の設定
      export WORDPRESS_DB_HOST="${module.rds.db_endpoint}"
      export WORDPRESS_DB_PASSWORD="${var.db_password}"
      
      # Ansibleディレクトリに移動
      cd ansible
      
      # SSH接続テスト
      echo "SSH接続をテスト中..."
      if ansible wordpress -m ping -i inventory/hosts.yml; then
        echo "✓ SSH接続成功"
      else
        echo "✗ SSH接続に失敗しました。サーバーの起動を待機中..."
        sleep 30
        if ansible wordpress -m ping -i inventory/hosts.yml; then
          echo "✓ SSH接続成功（再試行）"
        else
          echo "✗ SSH接続に失敗しました"
          exit 1
        fi
      fi
      
      # WordPress環境構築の実行
      echo "WordPress環境構築を開始中..."
      if ansible-playbook -i inventory/hosts.yml playbooks/step_by_step_setup.yml; then
        echo "✓ WordPress環境構築が完了しました"
      else
        echo "✗ WordPress環境構築に失敗しました"
        exit 1
      fi
      
      # 元のディレクトリに戻る
      cd ..
      
      echo ""
      echo "WordPress環境構築が完了しました！"
      echo "アクセス情報:"
      echo "- WordPress URL: https://${var.domain_name}"
      echo "- 管理画面: https://${var.domain_name}/wp-admin"
    EOT
  }

  depends_on = [module.ec2, module.ssh, module.rds, null_resource.ansible_setup]
}

# -----------------------------------------------------------------------------
# SSL Setup Resource
# -----------------------------------------------------------------------------

resource "null_resource" "ssl_setup" {
  count = var.enable_ssl_setup ? 1 : 0
  
  triggers = {
    domain_name = var.domain_name
    acm_certificate_arn = module.acm.certificate_arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Ansibleディレクトリに移動
      cd ansible
      
      # ACM証明書の状態を確認
      echo "ACM証明書の状態を確認中..."
      CERT_STATUS=$(aws acm describe-certificate \
        --certificate-arn "${module.acm.certificate_arn}" \
        --region us-east-1 \
        --query 'Certificate.Status' \
        --output text 2>/dev/null || echo "UNKNOWN")
      
      echo "証明書の状態: $CERT_STATUS"
      
      # 証明書が発行済みの場合のみSSL設定を実行
      if [ "$CERT_STATUS" = "ISSUED" ]; then
        echo "SSL証明書の設定を開始中..."
        if ansible-playbook -i inventory/hosts.yml playbooks/ssl_setup.yml; then
          echo "✓ SSL証明書の設定が完了しました"
        else
          echo "✗ SSL証明書の設定に失敗しました"
          exit 1
        fi
      else
        echo "証明書がまだ発行されていません。状態: $CERT_STATUS"
        echo "証明書の発行を待機中..."
        exit 0
      fi
      
      # 元のディレクトリに戻る
      cd ..
    EOT
  }

  depends_on = [module.acm, null_resource.wordpress_setup]
}

# -----------------------------------------------------------------------------
# Environment Testing Resource
# -----------------------------------------------------------------------------

resource "null_resource" "environment_test" {
  triggers = {
    wordpress_public_ip = module.ec2.public_ip
    domain_name = var.domain_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "環境テストを開始中..."
      
      # WordPress環境のテスト
      if [ -f "./scripts/test_environment.sh" ]; then
        echo "WordPress環境をテスト中..."
        ./scripts/test_environment.sh
      fi
      
      # 監視設定のテスト
      if [ -f "./scripts/test_monitoring.sh" ]; then
        echo "監視設定をテスト中..."
        ./scripts/test_monitoring.sh
      fi
      
      # デプロイメントテスト
      if [ -f "./scripts/deployment/test_environment.sh" ]; then
        echo "デプロイメント環境をテスト中..."
        ./scripts/deployment/test_environment.sh
      fi
      
      echo "✓ 環境テストが完了しました"
    EOT
  }

  depends_on = [null_resource.ssl_setup[0]]
}

# -----------------------------------------------------------------------------
# Infrastructure Summary
# -----------------------------------------------------------------------------

output "infrastructure_summary" {
  description = "インフラストラクチャの概要"
  value = {
    project = var.project
    environment = var.environment
    region = var.aws_region
    vpc_cidr = var.vpc_cidr
    domain_name = var.domain_name
  }
}

# -----------------------------------------------------------------------------
# Network Information
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPCのID"
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "パブリックサブネットのID一覧"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  value       = module.network.private_subnet_ids
}

# -----------------------------------------------------------------------------
# EC2 Information
# -----------------------------------------------------------------------------

output "wordpress_public_ip" {
  description = "WordPress EC2インスタンスのパブリックIP"
  value       = module.ec2.public_ip
}

output "wordpress_public_dns" {
  description = "WordPress EC2インスタンスのパブリックDNS"
  value       = module.ec2.public_dns
}

output "wordpress_instance_id" {
  description = "WordPress EC2インスタンスのID"
  value       = try(module.ec2.instance_id, null)
}

output "wordpress_availability_zone" {
  description = "WordPress EC2インスタンスのアベイラビリティゾーン"
  value       = try(module.ec2.availability_zone, null)
}

# -----------------------------------------------------------------------------
# NAT Instance Information
# -----------------------------------------------------------------------------

output "nat_instance_public_ip" {
  description = "NATインスタンスのパブリックIP"
  value       = module.nat_instance.nat_eip
}

output "nat_instance_id" {
  description = "NATインスタンスのID"
  value       = try(module.nat_instance.nat_instance_id, null)
}

# -----------------------------------------------------------------------------
# RDS Information
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "RDSエンドポイント"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "RDSポート"
  value       = try(module.rds.db_port, null)
}

output "rds_identifier" {
  description = "RDSインスタンス識別子"
  value       = try(module.rds.db_identifier, null)
}

output "rds_engine_version" {
  description = "RDSエンジンバージョン"
  value       = try(module.rds.db_engine_version, null)
}

# -----------------------------------------------------------------------------
# S3 Information
# -----------------------------------------------------------------------------

output "s3_bucket_name" {
  description = "S3バケット名"
  value       = try(module.s3.bucket_name, null)
}

output "s3_bucket_arn" {
  description = "S3バケットのARN"
  value       = try(module.s3.bucket_arn, null)
}

output "s3_bucket_domain_name" {
  description = "S3バケットのドメイン名"
  value       = try(module.s3.bucket_domain_name, null)
}

# -----------------------------------------------------------------------------
# ACM Information
# -----------------------------------------------------------------------------

output "acm_certificate_arn" {
  description = "ACM証明書のARN"
  value       = try(module.acm.certificate_arn, null)
}

output "acm_certificate_status" {
  description = "ACM証明書のステータス"
  value       = try(module.acm.certificate_status, null)
}

output "acm_validation_records" {
  description = "ACM証明書の検証レコード"
  value       = try(module.acm.validation_records, null)
}

# -----------------------------------------------------------------------------
# Route53 Information
# -----------------------------------------------------------------------------

output "name_servers" {
  description = "Route53ネームサーバー"
  value       = try(module.route53.name_servers, null)
}

output "domain_registration_status" {
  description = "ドメイン登録の状態"
  value       = try(module.route53.domain_registration_status, null)
}

output "domain_expiration_date" {
  description = "ドメインの有効期限"
  value       = try(module.route53.domain_expiration_date, null)
}

output "wordpress_dns_record" {
  description = "WordPress用DNSレコード"
  value       = try(module.route53.wordpress_dns_record, null)
}

# -----------------------------------------------------------------------------
# SSH Key Information
# -----------------------------------------------------------------------------

output "ssh_private_key" {
  description = "生成されたRSA秘密鍵（PEM形式）"
  value       = module.ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "生成されたRSA公開鍵（OpenSSH形式）"
  value       = module.ssh.public_key_openssh
}

output "ssh_key_name" {
  description = "SSHキーペア名"
  value       = try(module.ssh.key_name, null)
}

output "ssh_key_fingerprint" {
  description = "SSHキーのフィンガープリント"
  value       = try(module.ssh.key_fingerprint, null)
}

# -----------------------------------------------------------------------------
# Security Information
# -----------------------------------------------------------------------------

output "security_groups" {
  description = "セキュリティグループの情報"
  value = {
    ec2_public_sg_id = try(module.security.ec2_public_sg_id, null)
    ec2_private_sg_id = try(module.security.ec2_private_sg_id, null)
    rds_sg_id = try(module.security.rds_sg_id, null)
    nat_instance_sg_id = try(module.security.nat_instance_sg_id, null)
  }
}

# -----------------------------------------------------------------------------
# Validation Environment Information
# -----------------------------------------------------------------------------

output "validation_private_ip" {
  description = "検証用EC2インスタンスのプライベートIP"
  value       = module.ec2.validation_private_ip
}

output "validation_instance_id" {
  description = "検証用EC2インスタンスのID"
  value       = try(module.ec2.validation_instance_id, null)
}

output "validation_rds_endpoint" {
  description = "検証用RDSエンドポイント"
  value       = try(module.rds.validation_db_endpoint, null)
}

# -----------------------------------------------------------------------------
# CloudFront Information (When Enabled)
# -----------------------------------------------------------------------------

# CloudFront outputs are commented out since the module is disabled
# output "cloudfront_distribution_id" {
#   description = "CloudFrontディストリビューションのID"
#   value       = try(module.cloudfront[0].distribution_id, null)
# }

# output "cloudfront_domain_name" {
#   description = "CloudFrontディストリビューションのドメイン名"
#   value       = try(module.cloudfront[0].domain_name, null)
# }

# -----------------------------------------------------------------------------
# Module Status Information
# -----------------------------------------------------------------------------

output "module_status" {
  description = "各モジュールの有効化状態"
  value = {
    ssh_enabled = true
    nat_instance_enabled = true
    network_enabled = true
    security_enabled = true
    ec2_enabled = true
    rds_enabled = true
    s3_enabled = true
    acm_enabled = true
    cloudfront_enabled = false  # 一時的に無効化
    route53_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Security Features Status
# -----------------------------------------------------------------------------

output "security_features_status" {
  description = "セキュリティ機能の有効化状態"
  value = {
    ssh_key_rotation = try(module.ssh.security_features_enabled.key_rotation, false)
    ssh_backup = try(module.ssh.security_features_enabled.backup, false)
    ssh_audit_logs = try(module.ssh.security_features_enabled.audit_logs, false)
    rds_encryption = try(module.rds.storage_encrypted, false)
    rds_deletion_protection = try(module.rds.deletion_protection, false)
    s3_encryption = try(module.s3.encryption_enabled, false)
    s3_versioning = try(module.s3.versioning_enabled, false)
    s3_public_access_blocked = try(module.s3.public_access_blocked, false)
  }
}

# -----------------------------------------------------------------------------
# Monitoring Information
# -----------------------------------------------------------------------------

output "monitoring_resources" {
  description = "監視リソースの情報"
  value = {
    ssh_audit_log_group = try(module.ssh.audit_log_group_name, null)
    rds_cloudwatch_logs = try(module.rds.cloudwatch_log_groups, null)
    s3_access_logs = try(module.s3.access_logs_bucket_name, null)
  }
}

# -----------------------------------------------------------------------------
# Connection Information
# -----------------------------------------------------------------------------

output "connection_info" {
  description = "接続情報"
  value = {
    wordpress_url = "http://${try(module.ec2.public_ip, "N/A")}"
    wordpress_https_url = "https://${var.domain_name}"
    ssh_command = "ssh -i ssh_key.pem ec2-user@${try(module.ec2.public_ip, "N/A")}"
    rds_connection_string = "mysql://root:${var.db_password}@${try(module.rds.db_endpoint, "N/A")}:${try(module.rds.db_port, "3306")}/wordpress"
  }
  sensitive = true
}
