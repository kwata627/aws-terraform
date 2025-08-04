# =============================================================================
# RDS Module
# =============================================================================
# 
# このモジュールはAWS RDSインスタンスを作成し、WordPress環境の
# データベース基盤を提供します。セキュリティ強化と監視機能を
# 考慮した設計となっています。
#
# 特徴:
# - セキュリティ強化された設定
# - 柔軟なバックアップ設定
# - 監視・ログ機能対応
# - マルチAZ対応
# - 詳細なタグ管理
# =============================================================================

# -----------------------------------------------------------------------------
# Required Providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    {
      Name        = "${var.project}-db-subnet-group"
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# DB Parameter Group
# -----------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.project}-db-parameter-group"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    {
      Name        = "${var.project}-db-parameter-group"
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "rds_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/rds/instance/${var.rds_identifier}/mysql"
  retention_in_days = 30

  tags = merge(
    {
      Name        = "${var.project}-rds-logs"
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring (Optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name = "${var.project}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project}-rds-monitoring-role"
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# Production RDS Instance
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = var.rds_identifier

  # エンジン設定
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  # ストレージ設定
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted      = var.storage_encrypted
  kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null

  # データベース設定
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # ネットワーク設定
  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible     = var.publicly_accessible
  multi_az               = var.multi_az

  # パラメータグループ
  parameter_group_name = aws_db_parameter_group.main.name

  # バックアップ設定
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # セキュリティ設定
  deletion_protection = var.deletion_protection

  # 監視・ログ設定
  monitoring_interval = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_period : null

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["mysql", "error"] : []

  # 削除設定
  skip_final_snapshot = true

  tags = merge(
    {
      Name        = var.rds_identifier
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
      Purpose     = "wordpress-production"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Validation RDS Instance (Optional)
# -----------------------------------------------------------------------------

resource "aws_db_instance" "validation" {
  count = var.enable_validation_rds ? 1 : 0

  identifier = "${var.rds_identifier}-validation"

  # エンジン設定
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  # ストレージ設定
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted      = var.storage_encrypted
  kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null

  # データベース設定
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # ネットワーク設定
  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible     = var.publicly_accessible
  multi_az               = false  # 検証用はシングルAZ

  # パラメータグループ
  parameter_group_name = aws_db_parameter_group.main.name

  # バックアップ設定（検証用は短縮）
  backup_retention_period = 1
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # セキュリティ設定（検証用は無効）
  deletion_protection = false

  # 監視・ログ設定（検証用は最小限）
  monitoring_interval = 0
  monitoring_role_arn = null

  # Performance Insights（検証用は無効）
  performance_insights_enabled = false

  # CloudWatch Logs（検証用は無効）
  enabled_cloudwatch_logs_exports = []

  # スナップショットからの復元（指定がある場合）
  snapshot_identifier = var.validation_rds_snapshot_identifier != "" ? var.validation_rds_snapshot_identifier : null

  # 削除設定
  skip_final_snapshot = true

  tags = merge(
    {
      Name        = "${var.rds_identifier}-validation"
      Environment = var.environment
      Module      = "rds"
      ManagedBy   = "terraform"
      Purpose     = "wordpress-validation"
    },
    var.tags
  )
}
