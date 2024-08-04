variable "key_name" {
  type        = string
  description = "Sets the key name for the VPN instance"
  default     = "vpn-ssh-key"
}

variable "wg_clients" {
  type = list(object({
    name          = string
    address       = string
    public_key    = string
    private_key   = optional(string, "")
    preshared_key = string
  }))

  default = []
}

variable "instances" {
  type = map(list(object({
    name       = string
    private_ip = string
    // Unique identifier for an instance; used in a path for proxy.
    // e.g. t2.nano
    instance_type = optional(string, "t2.micro")
    # WireGuard VPN / wg-easy variables:
    wg_easy_password_hash = optional(string)
    vm_user               = optional(string, "ubuntu")
    wg_vpn_server_address = optional(string, "10.1.1.0")
    wg_vpn_mask           = optional(string, "10.1.1.x")
    wg_dns                = optional(string, "1.1.1.1")
    wg_port               = optional(string, "51820")
    wg_easy_web_port      = optional(string, "51821")
  })))

  default = {}
}

variable "wg_server_private_key" {
  type        = string
  description = "A preset private key for a WireGuard server."
  default     = ""
}

variable "wg_easy_password_hash" {
  type        = string
  description = "Hashed password for the WireGuard admin user. Set with the unescaped $ character."
}
