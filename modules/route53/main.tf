# ----- Route53ホストゾーンの作成 -----

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