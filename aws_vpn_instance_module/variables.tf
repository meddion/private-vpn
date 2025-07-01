variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t4g.nano"
}

variable "user_data" {
  type        = string
  description = "Sets the path to the user data script"
}

variable "instance_name" {
  type        = string
  description = "Sets the name for the VPN instance"
}

variable "key_name" {
  type        = string
  description = "Sets the key name for the VPN instance"
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}

variable "private_ip" {
  description = "The private IP address of the instance"
  type        = string
}

variable "security_group_id" {
  description = "The ID of the security group"
  type        = string
}

variable "use_spot_instance" {
  type        = bool
  description = "Set to true to use a spot instance"
  default     = false
}
