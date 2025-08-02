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

# ----- ルートテーブル(プライベート)の定義 -----

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-rt-private"
  }
}

# ----- NATインスタンス用のルート追加（後から設定） -----
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_instance_network_interface_id

  depends_on = []
}

# ----- サブネットとルートテーブルの関連付け（プライベート） -----

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

# プライベートサブネット1cのルートテーブル関連付けを追加
resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private.id
}
