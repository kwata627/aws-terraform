# ----- セキュリティグループの作成 -----

# --- EC2用セキュリティグループ（パブリックサブネット用） ---
resource "aws_security_group" "ec2_public" {
  name        = "${var.project}-sg-ec2-public"
  description = "EC2 public subnet SG"
  vpc_id      = var.vpc_id

  # SSH接続（22番ポート）
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                    # 注意：本番環境では特定IPに制限
  }

  # ICMP（ping用）
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP接続（80番ポート）
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS接続（443番ポート）
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド通信（全て許可）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-ec2-public"
  }
}

# --- RDS用セキュリティグループ（プライベートサブネット用） ---
resource "aws_security_group" "rds" {
  name        = "${var.project}-sg-rds"
  description = "RDS private subnet SG"
  vpc_id      = var.vpc_id

  # MySQL接続（3306番ポート）
  ingress {
    description     = "MySQL"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_public.id]  # EC2からの接続のみ許可
  }

  # アウトバウンド通信（制限なし）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-rds"
  }
}

# --- NATインスタンス用セキュリティグループ（パブリックサブネット用） ---
resource "aws_security_group" "nat_instance" {
  name        = "${var.project}-sg-nat-instance"
  description = "NAT instance SG" # ASCIIのみ
  vpc_id      = var.vpc_id

  # SSH接続（22番ポート）
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 必要に応じて制限
  }

  # ICMP（ping用）
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP（80番）
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS（443番）
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド通信（全て許可）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-nat-instance"
  }
}

# --- 検証用EC2専用セキュリティグループ（プライベートサブネット用） ---
resource "aws_security_group" "ec2_private" {
  name        = "${var.project}-sg-ec2-private"
  description = "EC2 private subnet SG for validation"
  vpc_id      = var.vpc_id

  # SSH接続（22番ポート）- NATインスタンス経由での接続を想定
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC内からの接続のみ許可
  }

  # HTTP接続（80番ポート）- 内部からのアクセス用
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTPS接続（443番ポート）- 内部からのアクセス用
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # アウトバウンド通信（全て許可）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-ec2-private"
  }
}