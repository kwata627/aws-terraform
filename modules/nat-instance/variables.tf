variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "subnet_id" {
  description = "NATインスタンスを配置するパブリックサブネットID"
  type        = string
}

variable "security_group_id" {
  description = "NATインスタンス用のセキュリティグループID"
  type        = string
}

variable "ami_id" {
  description = "NATインスタンス用AMI ID（Amazon Linux 2023）"
  type        = string
}

variable "instance_type" {
  description = "NATインスタンスのインスタンスタイプ（例: t3.nano）"
  type        = string
  default     = "t3.nano"
}

variable "key_name" {
  description = "SSHキーペア名"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH公開鍵の内容"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH秘密鍵の内容（検証用インスタンス接続用）"
  type        = string
  sensitive   = true
} 