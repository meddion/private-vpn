# data "aws_instances" "vpn_instances" {
#   instance_tags = {
#     "aws:autoscaling:groupName" = aws_autoscaling_group.vpn_asg.name
#   }
#   instance_state_names = ["running"]
# }


# output "vpn_asg_name" {
#   value = aws_autoscaling_group.vpn_asg.name
# }

# output "vpn_instance_public_ip" {
#   value = one(data.aws_instances.vpn_instances.public_ips)
# }

output "vpn_instance_name" {
  value = aws_instance.vpn_instance.tags_all["Name"]
}

output "vpn_instance_public_ip" {
  value = aws_instance.vpn_instance.public_ip
}

output "vpn_launch_template_name" {
  value = aws_launch_template.vpn_launch_template.name
}
