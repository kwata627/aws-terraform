terraform {
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
	required_version = ">= 1.4.0"
}

provider "aws" {
	region = var.aws_region
	profile = var.aws_profile
	
	# 認証情報を明示的に指定
	default_tags {
		tags = {
			Project = var.project
		}
	}
}

