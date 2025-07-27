# ----- VPCリソースの作成 -----

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr         # VPCのIP範囲（10.0.0.0/16）
  enable_dns_hostnames = true                 # EC2インスタンスにパブリックDNSホスト名を割当
  enable_dns_support   = true                 # DNS解決の有効化

	tags = {
    Name = "${var.project}-vpc"               # VPCリソースのタグ名
	}
}

# ----- サブネットの作成 -----

# --- パブリックサブネット ---
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id           # 紐付けるVPCのID
  cidr_block              = var.public_subnet_cidr    # サブネットのIP範囲（10.0.1.0/24）
  availability_zone       = var.az1                   # アベイラビリティゾーン（例: ap-northeast-1a）
  map_public_ip_on_launch = true                      # インスタンス起動時にパブリックIPを自動割当

	tags = {
    Name = "${var.project}-public-1a"                 # サブネットのタグ名
	}
}

# --- プライベートサブネット1a ---
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "${var.project}-private-1a"
  }
}

# --- プライベートサブネット1c ---
resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "${var.project}-private-1c"
  }
}

# ----- IGWの作成 -----

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                            # アタッチするVPCのID

        tags = {
    Name = "${var.project}-igw"
        }
}

# ----- ルートテーブル(パブリック)の定義 -----

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
	
	route {
    cidr_block = "0.0.0.0/0"                          # 全ての宛先
    gateway_id = aws_internet_gateway.igw.id          # IGW経由で外部アクセス
	}

        tags = {
    Name = "${var.project}-rt-public"
        }
}

# ----- サブネットとルートテーブルの関連付け（パブリック） -----

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

# ----- Elastic IPの確保（NAT用） -----

resource "aws_eip" "nat_eip" {
  domain = "vpc"
	
	tags = {
    Name = "${var.project}-nat-eip"
	}
}

# ----- NAT Gatewayの作成 -----

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id                  # EIPを割当
  subnet_id     = aws_subnet.public_1a.id             # パブリックサブネットに配置

        tags = {
    Name = "${var.project}-natgw"
        }

  depends_on = [aws_internet_gateway.igw]             # IGW作成後にNAT作成
}

# ----- ルートテーブル(プライベート)の定義 -----

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

        route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id           # NAT Gateway経由で外部アクセス
        }

        tags = {
    Name = "${var.project}-rt-private"
        }
}

# ----- サブネットとルートテーブルの関連付け（プライベート） -----

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}
