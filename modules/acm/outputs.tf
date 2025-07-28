output "certificate_arn" {
  description = "作成したACM証明書のARN"
  value       = aws_acm_certificate.main.arn
}

output "validation_records" {
  description = "DNS検証用のレコード情報"
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}
