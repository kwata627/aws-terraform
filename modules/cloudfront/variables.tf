variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "origin_domain_name" {
  description = "CloudFrontのオリジンドメイン名（S3バケットのドメイン名）"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM証明書のARN（HTTPS用）"
  type        = string
}