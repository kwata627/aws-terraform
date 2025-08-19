# =============================================================================
# SSH Module - SSH Key Pairs
# =============================================================================
# 
# このファイルはSSHモジュールのSSHキーペア定義を含みます。
# セキュアな鍵生成とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# TLS Private Key Generation
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh" {
  algorithm = local.ssh_key_config.algorithm
  rsa_bits  = local.ssh_key_config.algorithm == "RSA" ? local.ssh_key_config.rsa_bits : null
  ecdsa_curve = local.ssh_key_config.algorithm == "ECDSA" ? local.ssh_key_config.ecdsa_curve : null
}

# -----------------------------------------------------------------------------
# AWS Key Pair
# -----------------------------------------------------------------------------

resource "aws_key_pair" "ssh" {
  key_name   = local.ssh_key_config.name
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(
    local.common_tags,
    {
      Name = local.ssh_key_config.name
      Purpose = "ssh-key-pair"
      SecurityLevel = "high"
      Algorithm = local.ssh_key_config.algorithm
      KeySize = local.ssh_key_config.algorithm == "RSA" ? local.ssh_key_config.rsa_bits : local.ssh_key_config.ecdsa_curve
    }
  )
}

# -----------------------------------------------------------------------------
# SSH Key Backup (Optional)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "ssh_backup" {
  count = var.enable_backup ? 1 : 0
  
  bucket = "${var.project}-ssh-backup-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Purpose = "ssh-key-backup"
    }
  )
}

resource "aws_s3_bucket_versioning" "ssh_backup" {
  count = var.enable_backup ? 1 : 0
  
  bucket = aws_s3_bucket.ssh_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssh_backup" {
  count = var.enable_backup ? 1 : 0
  
  bucket = aws_s3_bucket.ssh_backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssh_backup" {
  count = var.enable_backup ? 1 : 0
  
  bucket = aws_s3_bucket.ssh_backup[0].id

  rule {
    id     = "ssh-key-backup-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

# -----------------------------------------------------------------------------
# SSH Key Audit Logs (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ssh_audit" {
  count = var.enable_audit_logs ? 1 : 0
  
  name              = "/aws/ssh/${var.project}/audit"
  retention_in_days = var.audit_retention_days

  tags = merge(
    local.common_tags,
    {
      Purpose = "ssh-audit"
    }
  )
}

# -----------------------------------------------------------------------------
# SSH Key Rotation IAM Role (Optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ssh_rotation" {
  count = var.enable_key_rotation ? 1 : 0
  
  name = "${var.project}-ssh-rotation-role"

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
      Purpose = "ssh-rotation"
    }
  )
}

resource "aws_iam_role_policy" "ssh_rotation" {
  count = var.enable_key_rotation ? 1 : 0
  
  name = "${var.project}-ssh-rotation-policy"
  role = aws_iam_role.ssh_rotation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeKeyPairs",
          "ec2:ImportKeyPair",
          "ec2:DeleteKeyPair",
          "s3:GetObject",
          "s3:PutObject",
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
# SSH Key File Creation (for Ansible) (Optimized)
# -----------------------------------------------------------------------------

resource "null_resource" "ssh_key_files" {
  triggers = {
    private_key = tls_private_key.ssh.private_key_pem
    public_key = tls_private_key.ssh.public_key_openssh
  }
  
  provisioner "local-exec" {
    command = "mkdir -p ~/.ssh && echo '${tls_private_key.ssh.private_key_pem}' > ~/.ssh/${aws_key_pair.ssh.key_name} && chmod 600 ~/.ssh/${aws_key_pair.ssh.key_name}"
  }
  
  provisioner "local-exec" {
    command = "echo '${tls_private_key.ssh.public_key_openssh}' > ~/.ssh/${aws_key_pair.ssh.key_name}.pub && chmod 644 ~/.ssh/${aws_key_pair.ssh.key_name}.pub"
  }
} 