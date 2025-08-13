# =============================================================================
# EC2 Instance Module
# =============================================================================
# 
# このモジュールはAWS EC2インスタンスを作成し、WordPress環境の基盤を
# 提供します。本番環境と検証環境の両方をサポートし、Ansibleとの
# 統合を考慮した設計となっています。
#
# 特徴:
# - 本番用と検証用の分離
# - 柔軟なUserDataテンプレート
# - セキュリティ強化された設定
# - 自動スケーリング対応
# - 詳細なモニタリング設定
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
# Production EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "wordpress" {
  # 基本設定
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # ネットワーク設定
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_id != null ? concat([var.security_group_id], var.security_group_ids) : var.security_group_ids
  associate_public_ip_address = var.associate_public_ip

  # ストレージ設定
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    delete_on_termination = var.delete_on_termination
    
    tags = merge(
      {
        Name        = "${var.project}-wordpress-root-volume"
        Environment = var.environment
        Module      = "ec2"
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }

  # インスタンスメタデータ設定
  metadata_options {
    http_tokens                 = "required"  # IMDSv2必須
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # モニタリング設定
  monitoring = var.enable_detailed_monitoring

  # シャットダウン動作
  instance_initiated_shutdown_behavior = var.shutdown_behavior

  # UserData設定
  user_data = base64encode(templatefile(
    var.user_data_template_path,
    {
      ssh_public_key = var.ssh_public_key
      project        = var.project
      environment    = var.environment
      additional_scripts = var.additional_user_data_scripts
    }
  ))

  # タグ設定
  tags = merge(
    {
      Name        = local.production_instance_name
      Environment = var.environment
      Module      = "ec2"
      ManagedBy   = "terraform"
      Purpose     = "wordpress-production"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Elastic IP for Production Instance
# -----------------------------------------------------------------------------

resource "aws_eip" "wordpress" {
  instance = aws_instance.wordpress.id
  domain   = "vpc"

  tags = merge(
    {
      Name        = "${var.project}-wordpress-eip"
      Environment = var.environment
      Module      = "ec2"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Validation EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "validation" {
  count = local.validation_enabled ? 1 : 0

  # 基本設定
  ami           = var.ami_id
  instance_type = var.validation_instance_type
  key_name      = var.key_name

  # ネットワーク設定（プライベートサブネット）
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.validation_security_group_id]
  associate_public_ip_address = false

  # ストレージ設定
  root_block_device {
    volume_size = var.validation_root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    delete_on_termination = var.delete_on_termination
    
    tags = merge(
      {
        Name        = "${var.project}-validation-root-volume"
        Environment = var.environment
        Module      = "ec2"
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }

  # インスタンスメタデータ設定
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # モニタリング設定
  monitoring = var.enable_detailed_monitoring

  # デフォルトで停止状態
  instance_initiated_shutdown_behavior = "stop"

  # UserData設定（検証用）
  user_data = base64encode(templatefile(
    var.validation_user_data_template_path,
    {
      ssh_public_key = var.ssh_public_key
      project        = var.project
      environment    = var.environment
      additional_scripts = var.additional_user_data_scripts
    }
  ))

  # タグ設定
  tags = merge(
    {
      Name        = local.validation_instance_name
      Environment = var.environment
      Module      = "ec2"
      ManagedBy   = "terraform"
      Purpose     = "wordpress-validation"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project}-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.wordpress.id
  }

  tags = merge(
    {
      Name        = "${var.project}-cpu-alarm"
      Environment = var.environment
      Module      = "ec2"
    },
    var.tags
  )
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors EC2 status checks"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.wordpress.id
  }

  tags = merge(
    {
      Name        = "${var.project}-status-check-alarm"
      Environment = var.environment
      Module      = "ec2"
    },
    var.tags
  )
}