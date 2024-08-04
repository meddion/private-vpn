output "vpc_id" {
  value = aws_vpc.vpn_vpc.id
}

output "subnet_id" {
  value = aws_subnet.vpn_pub_subnet.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.vpn_igw.id
}

output "route_table_id" {
  value = aws_route_table.vpn_pub_rtb.id
}

output "security_group_id" {
  value = aws_security_group.vpn_sg.id
}
