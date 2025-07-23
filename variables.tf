variable "aws_region" {
	description = "AWSのリージョン"
	default	= "ap-northeast-1"
}

variable "aws_profile" {
	description = "AWS CLIのプロファイル名"
	default = "default"
}

variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
  default     = "wp-demo"
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "パブリックサブネットのCIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "プライベートサブネットのCIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az1" {
  description = "利用するアベイラビリティゾーン"
  type        = string
  default     = "ap-northeast-1a"
}
