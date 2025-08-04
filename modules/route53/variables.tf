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
  default     = ""
}

variable "certificate_validation_records" {
  description = "ACM証明書検証用のDNSレコード情報"
  type = map(object({
    name   = string
    record = string
    type   = string
  }))
}

variable "register_domain" {
  description = "ドメイン登録を実行するかどうか"
  type        = bool
  default     = true
}

# ドメイン登録用の登録者情報
variable "registrant_info" {
  description = "ドメイン登録者の情報"
  type = object({
    first_name        = string
    last_name         = string
    organization_name = string
    email            = string
    phone_number     = string
    address_line_1   = string
    city             = string
    state            = string
    country_code     = string
    zip_code         = string
  })
  default = {
    first_name        = "Admin"
    last_name         = "User"
    organization_name = "My Organization"
    email            = "admin@example.com"
    phone_number     = "+81.1234567890"
    address_line_1   = "123 Main Street"
    city             = "Tokyo"
    state            = "Tokyo"
    country_code     = "JP"
    zip_code         = "100-0001"
  }
}