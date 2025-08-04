# =============================================================================
# Security Module - Security Audit Resources
# =============================================================================
# 
# このファイルはSecurityモジュールのセキュリティ監査機能を含みます。
# CloudWatch Logs、IAMロール、ポリシーを提供します。
# =============================================================================

# -----------------------------------------------------------------------------
# Security Audit CloudWatch Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "security_audit" {
  count = var.enable_security_audit ? 1 : 0
  
  name              = "/aws/security/${var.project}/audit"
  retention_in_days = var.security_audit_retention_days

  tags = merge(
    local.common_tags,
    {
      Purpose = "security-audit"
    }
  )
}

# -----------------------------------------------------------------------------
# Security Audit IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "security_audit" {
  count = var.enable_security_audit ? 1 : 0
  
  name = "${var.project}-security-audit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Purpose = "security-audit"
    }
  )
}

# -----------------------------------------------------------------------------
# Security Audit IAM Policy
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "security_audit" {
  count = var.enable_security_audit ? 1 : 0
  
  name = "${var.project}-security-audit-policy"
  role = aws_iam_role.security_audit[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Security Monitoring CloudWatch Alarms (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "security_violations" {
  count = var.enable_security_monitoring ? 1 : 0
  
  alarm_name          = "${var.project}-security-violations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityViolations"
  namespace           = "AWS/Security"
  period              = var.security_monitoring_interval * 60
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "セキュリティ違反が検出された場合のアラーム"
  alarm_actions       = var.security_notification_email != "" ? [aws_sns_topic.security_notifications[0].arn] : []

  tags = merge(
    local.common_tags,
    {
      Purpose = "security-monitoring"
    }
  )
}

# -----------------------------------------------------------------------------
# Security Notifications SNS Topic (Optional)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "security_notifications" {
  count = var.enable_security_monitoring && var.security_notification_email != "" ? 1 : 0
  
  name = "${var.project}-security-notifications"

  tags = merge(
    local.common_tags,
    {
      Purpose = "security-notifications"
    }
  )
}

resource "aws_sns_topic_subscription" "security_email" {
  count = var.enable_security_monitoring && var.security_notification_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.security_notifications[0].arn
  protocol  = "email"
  endpoint  = var.security_notification_email
}

# -----------------------------------------------------------------------------
# Security Compliance Resources (Optional)
# -----------------------------------------------------------------------------

resource "aws_config_configuration_recorder" "security_compliance" {
  count = var.enable_security_compliance ? 1 : 0
  
  name     = "${var.project}-security-compliance"
  role_arn = aws_iam_role.security_audit[0].arn

  recording_group {
    all_supported = true
  }
}

resource "aws_config_delivery_channel" "security_compliance" {
  count = var.enable_security_compliance ? 1 : 0
  
  name           = "${var.project}-security-compliance"
  s3_bucket_name = aws_s3_bucket.security_compliance[0].bucket

  depends_on = [aws_config_configuration_recorder.security_compliance]
}

resource "aws_s3_bucket" "security_compliance" {
  count = var.enable_security_compliance ? 1 : 0
  
  bucket = "${var.project}-security-compliance-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Purpose = "security-compliance"
    }
  )
}

resource "aws_s3_bucket_versioning" "security_compliance" {
  count = var.enable_security_compliance ? 1 : 0
  
  bucket = aws_s3_bucket.security_compliance[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_compliance" {
  count = var.enable_security_compliance ? 1 : 0
  
  bucket = aws_s3_bucket.security_compliance[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
} 