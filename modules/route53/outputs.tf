output "zone_id" {
  description = "作成したRoute53ホストゾーンのID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route53ホストゾーンのネームサーバー"
  value       = aws_route53_zone.main.name_servers
}

output "domain_registration_status" {
  description = "ドメイン登録の状態"
  value       = var.register_domain ? "Registered" : "Not registered"
}

output "domain_expiration_date" {
  description = "ドメインの有効期限"
  value       = var.register_domain ? "N/A" : "N/A"
}
