variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
  default     = "wp-demo-wordpress"
}

variable "s3_bucket_name" {
  description = "S3バケット名（suffixは自動付与）"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFrontディストリビューションのARN（S3バケットポリシー用）"
  type        = string
  default     = ""
}

variable "rds_identifier" {
  description = "RDSインスタンスの識別子"
  type        = string
  default     = "wp-demo-db"
}