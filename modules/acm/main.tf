# ----- ACM証明書の作成（HTTPS用） -----

# --- ACM証明書の作成 ---
resource "aws_acm_certificate" "main" {
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

