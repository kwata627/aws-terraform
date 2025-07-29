# ----- RDS（MySQL）の作成 -----

# --- サブネットグループの作成 ---
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [var.private_subnet_id_1, var.private_subnet_id_2]              # プライベートサブネットに配置

  tags = {
    Name = "${var.project}-db-subnet-group"
  }
}

# --- パラメータグループの作成 ---
resource "aws_db_parameter_group" "main" {
  family = "mysql8.0"                               # MySQL 8.0用
  name   = "${var.project}-db-parameter-group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  tags = {
    Name = "${var.project}-db-parameter-group"
  }
}

# --- RDSインスタンスの作成 ---
resource "aws_db_instance" "main" {
  identifier = var.rds_identifier                  # RDSインスタンスの識別子

  # エンジン設定
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class            # インスタンスタイプ（例: db.t3.micro）

  # ストレージ設定
  allocated_storage     = var.allocated_storage     # ストレージサイズ（GB）
  max_allocated_storage = var.max_allocated_storage # 自動拡張の最大サイズ
  storage_type          = "gp2"                     # 汎用SSD
  storage_encrypted      = true                     # ストレージ暗号化

  # データベース設定
  db_name  = var.db_name                           # データベース名
  username = var.db_username                       # マスターユーザー名
  password = var.db_password                       # マスターパスワード
  port     = 3306                                  # MySQLのデフォルトポート

  # ネットワーク設定
  vpc_security_group_ids = [var.rds_security_group_id]  # セキュリティグループ
  db_subnet_group_name   = aws_db_subnet_group.main.name # サブネットグループ

  # パラメータグループ
  parameter_group_name = aws_db_parameter_group.main.name

  # バックアップ設定
  backup_retention_period = 7                      # バックアップ保持期間（日）
  backup_window          = "03:00-04:00"           # バックアップ時間帯
  maintenance_window     = "sun:04:00-sun:05:00"   # メンテナンス時間帯

  # 削除保護（本番環境ではtrue推奨）
  deletion_protection = false

  # パブリックアクセス無効（プライベートサブネットのため）
  publicly_accessible = false

  # マルチAZ無効（コスト削減のため）
  multi_az = false

  skip_final_snapshot = true
  # final_snapshot_identifier = "wp-demo-db-final-${var.snapshot_date}"  # ← 一時的にコメントアウト

  tags = {
    Name = var.rds_identifier
  }
}
