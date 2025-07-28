output "zone_id" {
  description = "作成したRoute53ホストゾーンのID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route53ホストゾーンのネームサーバー"
  value       = aws_route53_zone.main.name_servers
}
