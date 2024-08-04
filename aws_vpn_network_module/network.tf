terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_vpc" "vpn_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpn-vpc"
  }
}

resource "aws_subnet" "vpn_pub_subnet" {
  vpc_id = aws_vpc.vpn_vpc.id

  availability_zone       = var.availability_zone
  cidr_block              = var.subnet_cidr_block
  map_public_ip_on_launch = "true"

  tags = {
    Name = "vpn-pub-subnet"
  }
}

resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "vpn-vpc-igw"
  }
}

resource "aws_route_table" "vpn_pub_rtb" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_igw.id
  }

  tags = {
    Name = "vpn-pub-rtb"
  }
}

resource "aws_route_table_association" "vpn_rtb_assoc" {
  subnet_id      = aws_subnet.vpn_pub_subnet.id
  route_table_id = aws_route_table.vpn_pub_rtb.id
}

resource "aws_security_group" "vpn_sg" {
  name        = "vpn-sg"
  description = "WireGuard Security Group"
  vpc_id      = aws_vpc.vpn_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # wg-easy listen port
  ingress {
    from_port   = 51821
    to_port     = 51821
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpn-sg"
  }
}
