# ----- Route53ドメイン登録とホストゾーンの作成 -----

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# --- ドメイン登録（新規追加） ---
resource "aws_route53domains_registered_domain" "main" {
  count = var.register_domain ? 1 : 0  # ドメイン登録フラグがtrueの場合のみ作成
  
  provider = aws.us_east_1  # us-east-1リージョンのプロバイダーを使用
  
  domain_name = var.domain_name

  # 登録者情報
  registrant_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 管理者情報（登録者と同じ）
  admin_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 技術担当者情報（登録者と同じ）
  tech_contact {
    first_name         = var.registrant_info.first_name
    last_name          = var.registrant_info.last_name
    organization_name  = var.registrant_info.organization_name
    email             = var.registrant_info.email
    phone_number      = var.registrant_info.phone_number
    address_line_1    = var.registrant_info.address_line_1
    city              = var.registrant_info.city
    state             = var.registrant_info.state
    country_code      = var.registrant_info.country_code
    zip_code          = var.registrant_info.zip_code
  }

  # 自動更新を有効化
  auto_renew = true

  tags = {
    Name    = "${var.project}-registered-domain"
    Project = var.project
  }
}

# --- ホストゾーンの作成 ---
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project}-hosted-zone"
  }
}

# --- Aレコードの作成（EC2用） ---
resource "aws_route53_record" "wordpress" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [var.wordpress_ip]
}

# --- CNAMEレコードの作成（CloudFront用） ---
resource "aws_route53_record" "cloudfront" {
  count = var.cloudfront_domain_name != "" ? 1 : 0 # 空文字でない場合のみ作成

  zone_id = aws_route53_zone.main.zone_id
  name    = "static.${var.domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [var.cloudfront_domain_name]
}

# --- ACM証明書検証用のレコード ---
resource "aws_route53_record" "cert_validation" {
  for_each = var.certificate_validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}