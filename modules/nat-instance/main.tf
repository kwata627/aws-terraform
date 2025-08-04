# =============================================================================
# NAT Instance Module
# =============================================================================
# 
# このモジュールはAWS EC2インスタンスを使用してNAT（Network Address Translation）
# インスタンスを作成し、プライベートサブネットからのインターネットアクセスを
# 提供します。NAT Gatewayの代替としてコスト効率的なソリューションです。
#
# 特徴:
# - コスト効率的なNATソリューション
# - セキュリティ強化された設定
# - 自動NAT設定
# - 高可用性対応
# - 詳細なモニタリング
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
# NAT Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "nat" {
  # 基本設定
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # ネットワーク設定
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  source_dest_check           = false  # NATインスタンス必須設定

  # ストレージ設定
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    delete_on_termination = var.delete_on_termination
    
    tags = merge(
      {
        Name        = "${var.project}-nat-root-volume"
        Environment = var.environment
        Module      = "nat-instance"
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
      ssh_private_key = var.ssh_private_key
      project        = var.project
      environment    = var.environment
      vpc_cidr       = var.vpc_cidr
      additional_scripts = var.additional_user_data_scripts
    }
  ))

  # タグ設定
  tags = merge(
    {
      Name        = "${var.project}-nat-instance"
      Environment = var.environment
      Module      = "nat-instance"
      ManagedBy   = "terraform"
      Purpose     = "nat-gateway"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Elastic IP for NAT Instance
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  instance = aws_instance.nat.id
  domain   = "vpc"

  tags = merge(
    {
      Name        = "${var.project}-nat-eip"
      Environment = var.environment
      Module      = "nat-instance"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "nat_cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project}-nat-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors NAT instance CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.nat.id
  }

  tags = merge(
    {
      Name        = "${var.project}-nat-cpu-alarm"
      Environment = var.environment
      Module      = "nat-instance"
    },
    var.tags
  )
}

resource "aws_cloudwatch_metric_alarm" "nat_status_check" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project}-nat-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors NAT instance status checks"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.nat.id
  }

  tags = merge(
    {
      Name        = "${var.project}-nat-status-check-alarm"
      Environment = var.environment
      Module      = "nat-instance"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Network Interface (for advanced routing)
# -----------------------------------------------------------------------------

resource "aws_network_interface" "nat" {
  count = var.enable_network_interface ? 1 : 0

  subnet_id         = var.subnet_id
  security_groups   = [var.security_group_id]
  source_dest_check = false

  tags = merge(
    {
      Name        = "${var.project}-nat-eni"
      Environment = var.environment
      Module      = "nat-instance"
      ManagedBy   = "terraform"
    },
    var.tags
  )
} 