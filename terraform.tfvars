# =============================================================================
# Terraform Variables Configuration (Optimized)
# =============================================================================
# 
# このファイルはTerraform変数の設定値を含みます。
# セキュアなインフラ設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

aws_region = "ap-northeast-1"
aws_profile = "default"

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

project = "wp-shamo"
environment = "production"

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
az1 = "ap-northeast-1a"

# -----------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------

ec2_name = "wp-shamo-ec2"
validation_ec2_name = "wp-test-ec2"
ami_id = "ami-095af7cb7ddb447ef"
instance_type = "t2.micro"
root_volume_size = 8

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------

rds_identifier = "wp-shamo-rds"
db_password = "breadhouse"  # RDSマスターパスワード
snapshot_date = ""

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------

s3_bucket_name = "wp-shamo-s3"

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

domain_name = "shamolife.com"
register_domain = false  # 自動判定されるため、通常はfalseのまま

# ドメイン登録者情報
registrant_info = {
  first_name        = "kazuki"
  last_name         = "watanabe"
  organization_name = "Personal"
  email            = "wata2watter0903@gmail.com"
  phone_number     = "+81.80-4178-3008"
  address_line_1   = "2-17-11"
  city             = "Niigata-shi, Chuo-ku"
  state            = "Niigata"
  country_code     = "JP"
  zip_code         = "9500915"
}

# -----------------------------------------------------------------------------
# Validation Environment Configuration
# -----------------------------------------------------------------------------

enable_validation_ec2 = true    # 検証用EC2（停止状態で作成）
enable_validation_rds = false   # 検証用RDS（停止状態で作成）
validation_rds_snapshot_identifier = ""

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

# SSH接続許可IP（セキュリティ強化）
# 例: "203.0.113.0/24"  # 特定のIPレンジ
# 例: "192.168.1.0/24"   # ローカルネットワーク
# 注意: 本番環境では必ず特定IPに制限してください
ssh_allowed_cidr = "0.0.0.0/0"

# -----------------------------------------------------------------------------
# SSL/TLS Configuration (Let's Encrypt)
# -----------------------------------------------------------------------------

enable_ssl_setup = true
enable_lets_encrypt = true
lets_encrypt_email = "wata2watter0903@gmail.com"
lets_encrypt_staging = false  # 本番環境ではfalse

# -----------------------------------------------------------------------------
# Additional Tags
# -----------------------------------------------------------------------------

tags = {
  Owner       = "watanabe"
  Purpose     = "wordpress-infrastructure"
  CostCenter  = "development"
  Backup      = "enabled"
  Monitoring  = "enabled"
}

