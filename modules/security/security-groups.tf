# =============================================================================
# Security Module - Security Groups
# =============================================================================
# 
# このファイルはSecurityモジュールのセキュリティグループ定義を含みます。
# 動的セキュリティルールとベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# EC2 Public Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ec2_public" {
  name        = local.security_groups.ec2_public.name
  description = local.security_groups.ec2_public.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.security_groups.ec2_public.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.security_groups.ec2_public.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.security_groups.ec2_public.name
      Purpose = "ec2-public"
      SecurityLevel = "high"
    }
  )
}

# -----------------------------------------------------------------------------
# EC2 Private Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ec2_private" {
  name        = local.security_groups.ec2_private.name
  description = local.security_groups.ec2_private.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.security_groups.ec2_private.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      security_groups = try(ingress.value.security_groups, []) != [] ? [aws_security_group.ec2_public.id] : []
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.security_groups.ec2_private.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.security_groups.ec2_private.name
      Purpose = "ec2-private"
      SecurityLevel = "high"
    }
  )
}

# -----------------------------------------------------------------------------
# RDS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = local.security_groups.rds.name
  description = local.security_groups.rds.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.security_groups.rds.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      security_groups = try(ingress.value.security_groups, []) != [] ? [aws_security_group.ec2_public.id] : []
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.security_groups.rds.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.security_groups.rds.name
      Purpose = "rds"
      SecurityLevel = "critical"
    }
  )
}

# -----------------------------------------------------------------------------
# NAT Instance Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "nat_instance" {
  name        = local.security_groups.nat_instance.name
  description = local.security_groups.nat_instance.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.security_groups.nat_instance.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.security_groups.nat_instance.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.security_groups.nat_instance.name
      Purpose = "nat-instance"
      SecurityLevel = "high"
    }
  )
}

# -----------------------------------------------------------------------------
# ALB Security Group (Optional)
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  count = var.enable_alb_security_group ? 1 : 0

  name        = local.optional_security_groups.alb.name
  description = local.optional_security_groups.alb.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.optional_security_groups.alb.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.optional_security_groups.alb.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.optional_security_groups.alb.name
      Purpose = "alb"
      SecurityLevel = "medium"
    }
  )
}

# -----------------------------------------------------------------------------
# Cache Security Group (Optional)
# -----------------------------------------------------------------------------

resource "aws_security_group" "cache" {
  count = var.enable_cache_security_group ? 1 : 0

  name        = local.optional_security_groups.cache.name
  description = local.optional_security_groups.cache.description
  vpc_id      = var.vpc_id

  # 動的イングレスルール
  dynamic "ingress" {
    for_each = [
      for rule in local.optional_security_groups.cache.rules.ingress : rule
      if rule.enabled
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      security_groups = try(ingress.value.security_groups, []) != [] ? [aws_security_group.ec2_public.id] : []
    }
  }

  # 動的エグレスルール
  dynamic "egress" {
    for_each = local.optional_security_groups.cache.rules.egress
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.optional_security_groups.cache.name
      Purpose = "cache"
      SecurityLevel = "high"
    }
  )
} 