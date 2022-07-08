# ------------------------------------------------------
# ------------------------------------------------------
# VM Settings:
variable "location" { default = "australiaeast" }
variable "vm_size" {
  default  = "Standard_A1_v2"
  nullable = false
}

variable "image_publisher" {
  default  = "Canonical"
  nullable = false
}
variable "image_name" {
  default  = "0001-com-ubuntu-server-focal"
  nullable = false
}
variable "image_version" {
  default  = "20_04-lts"
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
# ------------------------------------------------------
# ------------------------------------------------------

# ----------
# Misc Setup
# ----------
# Set the Provider
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "tf_group" {
  name     = "tf_group"
  location = var.location

  tags = {
    environment = "Terraform"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "tf_network" {
  name                = "tf_vnet"
  address_space       = ["10.61.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.tf_group.name

  tags = {
    environment = "Terraform"
  }
}

# Create subnet
resource "azurerm_subnet" "tf_subnet" {
  name                 = "tf_subnet"
  resource_group_name  = azurerm_resource_group.tf_group.name
  virtual_network_name = azurerm_virtual_network.tf_network.name
  address_prefixes     = ["10.61.61.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "tf_public_ip" {
  name                = "tf_public_ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.tf_group.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "tf_nsg" {
  name                = "tf_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tf_group.name

  security_rule {
    name                       = "Ping"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.ssh_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "WireGuard"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.wg_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllOut"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform"
  }
}

# Create network interface
resource "azurerm_network_interface" "tf_nic" {
  name                = "tf_nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.tf_group.name

  ip_configuration {
    name                          = "tf_nic_configuration"
    subnet_id                     = azurerm_subnet.tf_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf_public_ip.id
  }

  tags = {
    environment = "Terraform"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "tf_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.tf_nic.id
  network_security_group_id = azurerm_network_security_group.tf_nsg.id
}

# ----------------------
# Actual Virtual Machine
# ----------------------

# Create virtual machine
resource "azurerm_linux_virtual_machine" "tf_vm" {
  name                  = "tf_vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.tf_group.name
  network_interface_ids = [azurerm_network_interface.tf_nic.id]
  size                  = var.vm_size

  os_disk {
    name                 = "tf_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_name
    sku       = var.image_version
    version   = "latest"
  }

  computer_name                   = "tfvm"
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_key_pub)
  }

  custom_data = base64encode(templatefile(
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

  tags = {
    environment = "Terraform"
  }
}

# Output
output "username" {
  value = var.admin_username
}
output "ip_address" {
  value = azurerm_linux_virtual_machine.tf_vm.public_ip_address
}
output "ssh_port" {
  value = var.ssh_port
}
output "wg_port" {
  value = var.wg_port
}
