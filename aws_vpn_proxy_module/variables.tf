variable "instance_type" {
  type        = string
  description = "Sets the instance type for the VPN server"
}

variable "user_data" {
  description = "The user data to init a proxy instance"
  type        = string
}

variable "key_name" {
  description = "The name of the key pair"
  type        = string
}

variable "vpc_id" {
  type        = string
  description = "VPC reference value"
}

variable "subnet_id" {
  type        = string
  description = "Subnet reference value"
}
