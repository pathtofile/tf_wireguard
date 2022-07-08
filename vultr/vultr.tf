# ------------------------------------------------------
# ------------------------------------------------------
# OCI Settings
variable "api_key" {
  type      = string
  sensitive = true
}

# VM Settings, sjc == Silicon Valley:
variable "os_name" { default = "Ubuntu 20.04 x64" }
variable "region" { default = "sjc" }
variable "vm_size" { default = "vc2-1c-1gb" }
variable "public_iface" { default = "enp1s0" }

# Cloud Init settings
variable "init_script_template" { default = "cloud_init.yml.tftpl" }

# SSH settings:
variable "admin_username" { default = "ubuntu" }
variable "ssh_key_pub" { type = string }
variable "ssh_port" { default = 22 }

# Wireguard settings:
variable "wg_port" { default = 51820 }
variable "wg_client_pubkey" { type = string }
variable "wg_psk" {
  type      = string
  sensitive = true
}

# ------------------------------------------------------
# ------------------------------------------------------
# Define Provider
terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.9.1"
    }
  }
}
provider "vultr" {
  api_key = var.api_key
}

# Get Operating System Disk ID
data "vultr_os" "tf_os" {
  filter {
    name   = "name"
    values = [var.os_name]
  }
}

# Create FireWall and rules
resource "vultr_firewall_group" "tf_fw" {
  description = "terraform firewall group"
}
resource "vultr_firewall_rule" "tf_fw_ssh" {
  firewall_group_id = vultr_firewall_group.tf_fw.id
  subnet            = "0.0.0.0"
  subnet_size       = 0
  ip_type           = "v4"
  protocol          = "tcp"
  port              = tostring(var.ssh_port)
}
resource "vultr_firewall_rule" "tf_fw_wg" {
  firewall_group_id = vultr_firewall_group.tf_fw.id
  subnet            = "0.0.0.0"
  subnet_size       = 0
  ip_type           = "v4"
  protocol          = "udp"
  port              = tostring(var.wg_port)
}

# Create Instance
resource "vultr_instance" "tf_instance" {
  hostname    = "tfinstance"
  enable_ipv6 = false
  plan        = var.vm_size != "" ? var.vm_size : "vc2-1c-1gb"
  region      = var.region
  os_id       = data.vultr_os.tf_os.id
  user_data = templatefile(
    var.init_script_template,
    {
      wg_client_pubkey = var.wg_client_pubkey,
      wg_psk           = var.wg_psk,
      admin_username   = var.admin_username,
      admin_ssh_pubkey = file(var.ssh_key_pub),
      ssh_port         = var.ssh_port,
      wg_port          = var.wg_port,
      public_iface     = var.public_iface
  })
  firewall_group_id = vultr_firewall_group.tf_fw.id
}


# Output
output "username" {
  value = var.admin_username
}
output "ip_address" {
  value = vultr_instance.tf_instance.main_ip
}
output "ssh_port" {
  value = var.ssh_port
}
output "wg_port" {
  value = var.wg_port
}
