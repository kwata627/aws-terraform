terraform {
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
	required_version = ">= 1.4.0"
}

# メインリージョン（ap-northeast-1）のプロバイダー
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  # 認証情報を明示的に指定
  default_tags {
    tags = {
      Project = var.project
    }
  }
}

# us-east-1リージョンのプロバイダー（Route53 Domains用）
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}

