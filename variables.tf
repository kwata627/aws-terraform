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
  default     = "wp-shamo"
}

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
  default     = "wp-shamo-ec2"
}

variable "validation_ec2_name" {
  description = "検証用EC2インスタンスのNameタグ"
  type        = string
  default     = "wp-test-ec2"
}

variable "rds_identifier" {
  description = "RDSインスタンスの識別子"
  type        = string
  default     = "wp-shamo-rds"
}

variable "s3_bucket_name" {
  description = "S3バケット名（suffixは自動付与）"
  type        = string
  default     = "wp-shamo-s3"
}

variable "snapshot_date" {
  description = "スナップショット識別子用の日付 (例: 20250731)"
  type        = string
}

# SSH公開鍵の変数は削除（RSA鍵を自動生成するため）

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
  default     = "breadhouse"
}

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023）"
  type        = string
  default     = "ami-095af7cb7ddb447ef"
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
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

variable "enable_validation_ec2" {
  description = "検証用EC2インスタンスの作成有無"
  type        = bool
  default     = true
}

variable "enable_validation_rds" {
  description = "検証用RDSインスタンスの作成有無"
  type        = bool
  default     = false
}

variable "validation_rds_snapshot_identifier" {
  description = "検証用RDSのスナップショット識別子（空の場合は新規作成）"
  type        = string
  default     = ""
}
