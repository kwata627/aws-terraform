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
  # default     = "wp-demo"
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

variable "db_password" {
  description = "RDSマスターパスワード"
  type        = string
  sensitive   = true
}

variable "snapshot_date" {
  description = "スナップショット識別子用の日付 (例: 20250731)"
  type        = string
}

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023）"
  type        = string
  default     = "ami-0d52744d6551d851e"
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH接続用の公開鍵（~/.ssh/id_rsa.pub等の内容）"
  type        = string
}

variable "root_volume_size" {
  description = "ルートボリュームのサイズ（GB）"
  type        = number
  default     = 8
}

variable "domain_name" {
  description = "管理するドメイン名（例: example.com）"
  type        = string
}

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
  # default     = "wp-demo-wordpress"
}

variable "s3_bucket_name" {
  description = "S3バケット名（suffixは自動付与）"
  type        = string
  # default     = "wp-demo-static-files"
}

variable "rds_identifier" {
  description = "RDSインスタンスの識別子"
  type        = string
  # default     = "wp-demo-db"
}
