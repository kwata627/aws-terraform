variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023推奨）"
  type        = string
  default     = "ami-0d52744d6551d851e"  # Amazon Linux 2023 (ap-northeast-1)
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "EC2インスタンスを配置するサブネットID"
  type        = string
}

variable "security_group_id" {
  description = "EC2インスタンス用のセキュリティグループID"
  type        = string
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

variable "enable_validation_ec2" {
  description = "検証用EC2インスタンスの作成有無"
  type        = bool
  default     = false
}

variable "private_subnet_id" {
  description = "検証用EC2インスタンスを配置するプライベートサブネットID"
  type        = string
}

variable "validation_ec2_name" {
  description = "検証用EC2インスタンスのNameタグ"
  type        = string
}

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
}