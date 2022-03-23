# ------------------------------------------------------
# ------------------------------------------------------
# OCI Settings
variable "tenancy_ocid" {
  type      = string
  sensitive = true
}
variable "user_ocid" {
  type      = string
  sensitive = true
}
variable "api_fingerprint" { type = string }
variable "api_key_pri" { type = string }

# VM Settings:
variable "location" { default = "ap-sydney-1" }
variable "vm_shape" { default = "VM.Standard.E2.1.Micro" }

variable "image_name" { default = "Canonical Ubuntu" }
variable "image_version" { default = "20.04" }
variable "public_iface" { default = "ens3" }

# Cloud Init settings
variable "init_script_template" { default = "../cloud_init.yml.tftpl" }

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

provider "oci" {
  region           = var.location
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.api_fingerprint
  private_key_path = var.api_key_pri
}

# See https://docs.oracle.com/iaas/images/
data "oci_core_images" "tf_image" {
  compartment_id           = var.tenancy_ocid
  operating_system         = var.image_name
  operating_system_version = var.image_version
  shape                    = var.vm_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domain" "tf_ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

resource "oci_core_virtual_network" "tf_vcn" {
  cidr_block     = "172.16.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "testVCN"
  dns_label      = "testvcn"
}

resource "oci_core_subnet" "test_subnet" {
  cidr_block        = "172.16.20.0/24"
  display_name      = "testSubnet"
  dns_label         = "testsubnet"
  security_list_ids = [oci_core_security_list.tf_seclist.id]
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_virtual_network.tf_vcn.id
  route_table_id    = oci_core_route_table.tf_route.id
  dhcp_options_id   = oci_core_virtual_network.tf_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "tf_gateway" {
  compartment_id = var.tenancy_ocid
  display_name   = "testIG"
  vcn_id         = oci_core_virtual_network.tf_vcn.id
}

resource "oci_core_route_table" "tf_route" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_virtual_network.tf_vcn.id
  display_name   = "testRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tf_gateway.id
  }
}

resource "oci_core_security_list" "tf_seclist" {
  compartment_id = var.tenancy_ocid
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
  compartment_id      = var.tenancy_ocid
  display_name        = "tfinstance"
  shape               = var.vm_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.test_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "tfinstance"
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
        wg_client_pubkey = var.wg_client_pubkey,
        wg_psk           = var.wg_psk,
        admin_username   = var.admin_username,
        admin_ssh_pubkey = file(var.ssh_key_pub),
        ssh_port         = var.ssh_port,
        wg_port          = var.wg_port,
      public_iface     = var.public_iface
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
