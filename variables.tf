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

variable "ssh_allowed_cidr" {
  description = "SSH接続を許可するCIDRブロック（例: 203.0.113.0/24）"
  type        = string
  default     = "0.0.0.0/0"  # 注意：本番環境では特定IPに制限
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

variable "register_domain" {
  description = "ドメイン登録を実行するかどうか"
  type        = bool
  default     = true
}
