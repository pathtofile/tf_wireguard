module "mod" {
  source = "./aws"

  admin_username       = var.admin_username
  ssh_key_pub          = var.ssh_key_pub
  ssh_port             = var.ssh_port
  wg_client_pubkey     = var.wg_client_pubkey
  wg_server_prikey     = var.wg_server_prikey
  wg_psk               = var.wg_psk
  wg_port              = var.wg_port
  location             = var.location
  vm_size              = var.vm_size
  image_publisher      = var.image_publisher
  image_name           = var.image_name
  image_version        = var.image_version
  init_script_template = var.init_script_template
  api_key              = var.api_key
  extra_open_ports     = var.extra_open_ports
  enable_ssh_access    = var.enable_ssh_access
  dynamic_dns_command  = var.dynamic_dns_command
}

# VM Settings:
variable "location" { type = string }
variable "init_script_template" { default = "cloud_init.yml.tftpl" }
variable "vm_size" { default = null }
variable "image_publisher" { default = null }
variable "image_name" { default = null }
variable "image_version" { default = null }
variable "api_key" { default = null }

# SSH settings:
variable "admin_username" { default = "ubuntu" }
variable "ssh_key_pub" { default = "~/.ssh/id_rsa.pub" }
variable "ssh_port" { default = 22 }
# Enable ablility to log into server using ssh
variable "enable_ssh_access" {
  type    = bool
  default = false
}

# Wireguard settings:
variable "wg_port" { default = 51820 }
variable "wg_client_pubkey" { type = string }
variable "wg_psk" {
  type      = string
  sensitive = true
}
# Optional, will be autogenerated by default
variable "wg_server_prikey" {
  type      = string
  sensitive = true
  default   = ""
}

# HTTPS settings
variable "extra_open_ports" {
  type    = list(any)
  default = []
}

# DynamicDNS settings:
variable "dynamic_dns_command" { default = "" }

# Output
output "username" {
  value = module.mod.username
}
output "ip_address" {
  value = module.mod.ip_address
}
output "ssh_port" {
  value = module.mod.ssh_port
}
output "wg_port" {
  value = module.mod.wg_port
}
