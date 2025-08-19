# =============================================================================
# Terraform Provider Configuration (Refactored)
# =============================================================================
# 
# このファイルはTerraformプロバイダーの設定を含みます。
# セキュアなインフラ設定とベストプラクティスに沿った設計となっています。
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform Configuration
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # バックエンド設定（必要に応じて有効化）
  # backend "s3" {
  #   bucket = "terraform-state-bucket"
  #   key    = "terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}

# -----------------------------------------------------------------------------
# Main AWS Provider (ap-northeast-1)
# -----------------------------------------------------------------------------

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # デフォルトタグ設定
  default_tags {
    tags = merge(
      {
        Project     = var.project
        Environment = var.environment
        ManagedBy   = "terraform"
        Version     = "2.0.0"
      },
      var.tags
    )
  }

  # 認証情報の設定
  # 注意: 本番環境ではIAMロールまたは環境変数を使用することを推奨
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
}

# -----------------------------------------------------------------------------
# US East 1 Provider (for Route53 Domains and ACM)
# -----------------------------------------------------------------------------

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile

  # デフォルトタグ設定
  default_tags {
    tags = merge(
      {
        Project     = var.project
        Environment = var.environment
        ManagedBy   = "terraform"
        Version     = "2.0.0"
      },
      var.tags
    )
  }
}

