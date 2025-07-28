output "bucket_id" {
  description = "作成したS3バケットのID"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "作成したS3バケットのARN"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "S3バケットのドメイン名（CloudFrontオリジン用）"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}
