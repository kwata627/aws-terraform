variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "domain_name" {
  description = "管理するドメイン名（例: example.com）"
  type        = string
}

variable "wordpress_ip" {
  description = "WordPress EC2インスタンスのIPアドレス"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFrontディストリビューションのドメイン名"
  type        = string
}

variable "certificate_validation_records" {
  description = "ACM証明書検証用のDNSレコード情報"
  type = map(object({
    name   = string
    record = string
    type   = string
  }))
}