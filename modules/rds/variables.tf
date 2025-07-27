variable "project" {
  description = "プロジェクト名"
  type        = string
}

variable "private_subnet_id_1" {
  description = "プライベートサブネット1aのID"
  type        = string
}

variable "private_subnet_id_2" {
  description = "プライベートサブネット1cのID"
  type        = string
}

variable "rds_security_group_id" {
  description = "RDS用セキュリティグループのID"
  type        = string
}

variable "db_instance_class" {
  description = "RDSインスタンスタイプ"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "割り当てストレージサイズ（GB）"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "自動拡張の最大ストレージサイズ（GB）"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "データベース名"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "データベースマスターユーザー名"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "データベースマスターパスワード"
  type        = string
  sensitive   = true
}

variable "snapshot_date" {
  description = "スナップショット識別子用の日付 (例: 20250731)"
  type        = string
}