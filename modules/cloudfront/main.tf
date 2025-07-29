# ----- CloudFrontディストリビューションの作成 -----

# --- CloudFrontディストリビューション ---
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled    = true
  default_root_object = "index.html"

  # オリジンドメインの設定
  origin {
    domain_name = var.origin_domain_name
    origin_id   = "S3-${var.project}-static-files"

    # S3オリジンアクセス制御
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # デフォルトキャッシュビヘイビアの設定
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.project}-static-files"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # 価格クラスの設定
  price_class = "PriceClass_100"  # 北米・ヨーロッパ・アジア

  # 制限設定
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ビューワー証明書の設定
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${var.project}-cloudfront"
  }
}

# --- オリジンアクセス制御の設定 ---
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project}-oac"
  description                       = "S3オリジンアクセス制御"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}