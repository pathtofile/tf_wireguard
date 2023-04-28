# ------------------------------------------------------
# ------------------------------------------------------
# OCI Settings
variable "api_key" {
  type = object({
    tenancy_ocid    = string
    user_ocid       = string
    api_fingerprint = string
    api_key_pri     = string
  })
  sensitive = true
  nullable  = false
}

# VM Settings:
variable "vm_name" { default = "tfvm" }
variable "location" {
  default  = "ap-sydney-1"
  nullable = false
}
variable "vm_size" {
  default  = "VM.Standard.E2.1.Micro"
  nullable = false
}
variable "image_name" {
  default  = "Canonical Ubuntu"
  nullable = false
}
variable "image_version" {
  default  = "22.04"
  nullable = false
}
variable "public_iface" { default = "ens3" }

# Cloud Init settings
variable "init_script_template" { default = "cloud_init.yml.tftpl" }

# SSH settings:
variable "admin_username" { default = "ubuntu" }
variable "ssh_key_pub" { type = string }
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
  nullable  = false
}

# Extra settings
variable "extra_open_ports" {
  type    = set(any)
  default = []
}
variable "extra_packages" {
  type    = set(any)
  default = []
}
variable "extra_commands" {
  type    = set(any)
  default = []
}
variable "forward_ports" {
  type    = bool
  default = false
}

# Unused:
variable "image_publisher" { default = null }

# ------------------------------------------------------
# ------------------------------------------------------

provider "oci" {
  region           = var.location
  tenancy_ocid     = var.api_key.tenancy_ocid
  user_ocid        = var.api_key.user_ocid
  fingerprint      = var.api_key.api_fingerprint
  private_key_path = var.api_key.api_key_pri
}

# See https://docs.oracle.com/iaas/images/
data "oci_core_images" "tf_image" {
  compartment_id           = var.api_key.tenancy_ocid
  operating_system         = var.image_name
  operating_system_version = var.image_version
  shape                    = var.vm_size
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domain" "tf_ad" {
  compartment_id = var.api_key.tenancy_ocid
  ad_number      = 1
}

resource "oci_core_virtual_network" "tf_vcn" {
  cidr_block     = "172.16.0.0/16"
  compartment_id = var.api_key.tenancy_ocid
  display_name   = "testVCN"
  dns_label      = "testvcn"
}

resource "oci_core_subnet" "test_subnet" {
  cidr_block        = "172.16.20.0/24"
  display_name      = "testSubnet"
  dns_label         = "testsubnet"
  security_list_ids = [oci_core_security_list.tf_seclist.id]
  compartment_id    = var.api_key.tenancy_ocid
  vcn_id            = oci_core_virtual_network.tf_vcn.id
  route_table_id    = oci_core_route_table.tf_route.id
  dhcp_options_id   = oci_core_virtual_network.tf_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "tf_gateway" {
  compartment_id = var.api_key.tenancy_ocid
  display_name   = "testIG"
  vcn_id         = oci_core_virtual_network.tf_vcn.id
}

resource "oci_core_route_table" "tf_route" {
  compartment_id = var.api_key.tenancy_ocid
  vcn_id         = oci_core_virtual_network.tf_vcn.id
  display_name   = "testRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tf_gateway.id
  }
}

resource "oci_core_security_list" "tf_seclist" {
  compartment_id = var.api_key.tenancy_ocid
  vcn_id         = oci_core_virtual_network.tf_vcn.id
  display_name   = "testSecurityList"

  egress_security_rules {
    protocol    = "1"
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol    = "17"
    destination = "0.0.0.0/0"
  }

  # ICMP
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }

  # SSH over TCP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = tostring(var.ssh_port)
      min = tostring(var.ssh_port)
    }
  }

  # Any extra TCP Ports to open
  dynamic "ingress_security_rules" {
    for_each = var.extra_open_ports
    content {
      protocol = "6"
      source   = "0.0.0.0/0"

      tcp_options {
        max = tostring(ingress_security_rules.value)
        min = tostring(ingress_security_rules.value)
      }
    }
  }

  # WireGuard over UDP
  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"

    udp_options {
      max = tostring(var.wg_port)
      min = tostring(var.wg_port)
    }
  }
}

resource "oci_core_instance" "tf_instance" {
  availability_domain = data.oci_identity_availability_domain.tf_ad.name
  compartment_id      = var.api_key.tenancy_ocid
  display_name        = var.vm_name
  shape               = var.vm_size

  create_vnic_details {
    subnet_id        = oci_core_subnet.test_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = var.vm_name
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.tf_image.images[0], "id")
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_key_pub)
    user_data = base64encode(templatefile(
      var.init_script_template,
      {
        wg_client_pubkey  = file(var.wg_client_pubkey),
        wg_psk            = file(var.wg_psk),
        wg_server_prikey  = var.wg_server_prikey != "" ? file(var.wg_server_prikey) : "",
        admin_username    = var.admin_username,
        admin_ssh_pubkey  = file(var.ssh_key_pub),
        ssh_port          = var.ssh_port,
        wg_port           = var.wg_port,
        public_iface      = var.public_iface,
        enable_ssh_access = var.enable_ssh_access,
        extra_open_ports  = var.extra_open_ports,
        forward_ports     = var.forward_ports,
        extra_packages    = var.extra_packages,
        extra_commands    = var.extra_commands,
    }))
  }
}

# Output
output "username" {
  value = var.admin_username
}
output "ip_address" {
  value = oci_core_instance.tf_instance.public_ip
}
output "ssh_port" {
  value = var.ssh_port
}
output "wg_port" {
  value = var.wg_port
}
