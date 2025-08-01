variable "project" {
  description = "プロジェクト名（リソース名のprefix用）"
  type        = string
}

variable "vpc_cidr" {
	description = "VPCのCIDRブロック"
  type        = string
}

variable "public_subnet_cidr" {
  description = "パブリックサブネットのCIDR"
  type        = string
}

variable "private_subnet_cidr" {
  description = "プライベートサブネットのCIDR"
  type        = string
}

variable "az1" {
  description = "利用するアベイラビリティゾーン"
  type        = string
}

variable "nat_instance_network_interface_id" {
  description = "プライベートルート用NATインスタンスのネットワークインターフェースID（main.tfから渡す）"
  type        = string
}
