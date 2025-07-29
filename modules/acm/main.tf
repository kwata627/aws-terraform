# ----- ACM証明書の作成（HTTPS用） -----

# --- us-east-1リージョンのプロバイダー設定（CloudFront用） ---
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# --- ACM証明書の作成 ---
resource "aws_acm_certificate" "main" {
  provider = aws.us_east_1  # CloudFront用にus-east-1で作成
  domain_name       = var.domain_name
  validation_method = "DNS"

  # サブジェクト代替名（SAN）の設定
  subject_alternative_names = ["*.${var.domain_name}"]

  # 証明書の有効期限の設定
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-certificate"
  }
}

