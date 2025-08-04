# =============================================================================
# Network Module
# =============================================================================
# 
# このモジュールはAWS VPCとサブネットを作成し、WordPress環境の
# ネットワーク基盤を提供します。マルチAZ対応とセキュリティ強化を
# 考慮した設計となっています。
#
# 特徴:
# - マルチAZ対応
# - セキュリティ強化された設定
# - 柔軟なサブネット設計
# - 自動ルーティング設定
# - 詳細なタグ管理
# - VPC Flow Logs対応
# - VPCエンドポイント対応
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
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      Name        = "${var.project}-vpc"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.project}-igw"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index].cidr
  availability_zone       = var.public_subnets[count.index].az
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = var.public_subnets[count.index].name != null ? var.public_subnets[count.index].name : "${var.project}-public-${var.public_subnets[count.index].az}"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
      Type        = "public"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index].cidr
  availability_zone = var.private_subnets[count.index].az

  tags = merge(
    {
      Name        = var.private_subnets[count.index].name != null ? var.private_subnets[count.index].name : "${var.project}-private-${var.private_subnets[count.index].az}"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
      Type        = "private"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    {
      Name        = "${var.project}-rt-public"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.project}-rt-private"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# NAT Route (conditional)
resource "aws_route" "private_nat" {
  count = var.enable_nat_route ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_instance_network_interface_id
}

# -----------------------------------------------------------------------------
# Route Table Associations
# -----------------------------------------------------------------------------

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Network ACLs (Optional)
# -----------------------------------------------------------------------------

resource "aws_network_acl" "public" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id = aws_vpc.main.id

  # Inbound rules
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Outbound rules
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      Name        = "${var.project}-nacl-public"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "aws_network_acl" "private" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id = aws_vpc.main.id

  # Inbound rules (restrictive)
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 65535
  }

  # Outbound rules
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      Name        = "${var.project}-nacl-private"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Network ACL Associations
resource "aws_network_acl_association" "public" {
  count = var.enable_network_acls ? length(var.public_subnets) : 0

  network_acl_id = aws_network_acl.public[0].id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_network_acl_association" "private" {
  count = var.enable_network_acls ? length(var.private_subnets) : 0

  network_acl_id = aws_network_acl.private[0].id
  subnet_id      = aws_subnet.private[count.index].id
}

# -----------------------------------------------------------------------------
# VPC Endpoints (Optional)
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = merge(
    {
      Name        = "${var.project}-vpce-s3"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"

  tags = merge(
    {
      Name        = "${var.project}-vpce-dynamodb"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# VPC Flow Logs (Optional)
# -----------------------------------------------------------------------------

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.project}-flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = merge(
    {
      Name        = "${var.project}-vpc-flow-logs"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# IAM Role for Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.project}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project}-vpc-flow-logs-role"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# IAM Policy for Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.project}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
      }
    ]
  })
}

# VPC Flow Log
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn   = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.project}-vpc-flow-log"
      Environment = var.environment
      Module      = "network"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}
