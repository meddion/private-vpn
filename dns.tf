# variable "proxy_domain_name" {
#   type        = string
#   description = "Sets domain name for the reverse proxy"
# }

# resource "aws_route53_zone" "main" {
#   name = var.proxy_domain_name
# }
#
# resource "aws_route53_record" "www_proxy" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www.${var.proxy_domain_name}"
#   type    = "A"
#   ttl     = "300"
#   records = [module.aws_vpn_network.nginx_proxy_manager_public_ip]
# }
