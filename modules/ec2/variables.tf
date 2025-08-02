variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "ami_id" {
  description = "EC2インスタンス用のAMI ID（Amazon Linux 2023推奨）"
  type        = string
  default     = "ami-095af7cb7ddb447ef"  # Amazon Linux 2023 (ap-northeast-1)
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

variable "key_name" {
  description = "統一されたSSHキーペア名"
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

variable "ssh_public_key" {
  description = "SSH公開鍵の内容"
  type        = string
}

variable "validation_security_group_id" {
  description = "検証用EC2インスタンス用のセキュリティグループID"
  type        = string
}

variable "ec2_name" {
  description = "EC2インスタンスのNameタグ"
  type        = string
}