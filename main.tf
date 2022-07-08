module "mod" {
  source = "./aws"

  admin_username   = var.admin_username
  ssh_key_pub      = var.ssh_key_pub
  ssh_port         = var.ssh_port
  wg_client_pubkey = var.wg_client_pubkey
  wg_psk           = var.wg_psk
  wg_port          = var.wg_port
  location         = var.location
  vm_size          = var.vm_size
}

# VM Settings:
variable "init_script_template" { default = "cloud_init.yml.tftpl" }
variable "location" { type = string }
variable "vm_size" { default = null }

# SSH settings:
variable "admin_username" { default = "ubuntu" }
variable "ssh_key_pub" { default = "~/.ssh/id_rsa.pub" }
variable "ssh_port" { default = 22 }

# Wireguard settings:
variable "wg_port" { default = 51820 }
variable "wg_client_pubkey" { type = string }
variable "wg_psk" {
  type      = string
  sensitive = true
}

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
