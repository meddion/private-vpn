terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_template" "vpn_launch_template" {
  name_prefix   = var.instance_name
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = base64encode(var.user_data)

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
    subnet_id                   = var.subnet_id
  }

  dynamic "instance_market_options" {
    for_each = var.use_spot_instance ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price          = "0.005"
        spot_instance_type = "one-time"
      }
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.instance_name
    }
  }
}

resource "aws_autoscaling_group" "vpn_asg" {
  name_prefix = var.instance_name
  desired_capacity = 1
  max_size         = 1
  min_size         = 1

  vpc_zone_identifier = [var.subnet_id]

  launch_template {
    id      = aws_launch_template.vpn_launch_template.id
    version = "$Latest"
  }
}
