variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH接続用の公開鍵"
  type        = string
} 