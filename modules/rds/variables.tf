variable "project" {
  description = "プロジェクト名"
  type        = string
}

variable "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  type        = list(string)
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
  description = "スナップショット識別子用の日付 (例: 20240727)"
  type        = string
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

variable "rds_identifier" {
  description = "RDSインスタンスの識別子"
  type        = string
}