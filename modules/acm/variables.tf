variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "domain_name" {
  description = "SSL証明書を発行するドメイン名（例: example.com）"
  type        = string
}