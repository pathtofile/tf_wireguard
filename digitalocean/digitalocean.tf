# ------------------------------------------------------
# ------------------------------------------------------
# Access Settings, set  env variable to TF_VAR_xxxx:
variable "api_key" {
  type      = string
  sensitive = true
}

# VM settings:
variable "location" { default = "sfo3" }
variable "vm_size" {
  default  = "s-1vcpu-1gb"
  nullable = false
}
variable "image_name" {
  default  = "ubuntu-20-04-x64"
  nullable = false
}

variable "public_iface" { default = "eth0" }

# Cloud Init settings
variable "init_script_template" { default = "cloud_init.yml.tftpl" }

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

# Unused:
variable "image_publisher" { default = null }
variable "image_version" { default = null }

# ------------------------------------------------------
# ------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Set token
provider "digitalocean" {
  token = var.api_key
}

# Create a new SSH key
resource "digitalocean_ssh_key" "tf_keypair" {
  name       = "terraform_keypair"
  public_key = file(var.ssh_key_pub)
}

# Create firewall rules
resource "digitalocean_firewall" "tf_firewall" {
  name = "tf-firewall"

  droplet_ids = [digitalocean_droplet.tf_vm.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.ssh_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = tostring(var.wg_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create VM
resource "digitalocean_droplet" "tf_vm" {
  image    = var.image_name
  name     = "tfvm"
  region   = var.location
  size     = var.vm_size
  ssh_keys = [digitalocean_ssh_key.tf_keypair.fingerprint]

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

}

# Output
output "username" {
  value = var.admin_username
}
output "ip_address" {
  value = digitalocean_droplet.tf_vm.ipv4_address
}
output "ssh_port" {
  value = var.ssh_port
}
output "wg_port" {
  value = var.wg_port
}
