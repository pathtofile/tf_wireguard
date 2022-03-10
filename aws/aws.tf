# ------------------------------------------------------
# ------------------------------------------------------
# VM settings:
variable "location" { default = "us-west-1" }
variable "vm_size" { default = "t2.micro" }

variable "image_publisher" { default = "679593333241" }
variable "image_name" { default = "ubuntu-minimal/images/hvm-ssd/ubuntu-focal-20.04-*" }

# Cloud Init settings
variable "init_script_template" { default = "../cloud_init/cloud_init.yml.tftpl" }

# SSH settings:
variable "admin_username" { default = "ubuntu" }
variable "ssh_key_pub" { default = "~/.ssh/id_rsa.pub" }
variable "ssh_port" { default = 22 }

# Wireguard settings:
variable "wg_port" { default = 51821 }
variable "wg_client_pubkey" { type = string }
variable "wg_psk" {
  type      = string
  sensitive = true
}

# ------------------------------------------------------
# ------------------------------------------------------

provider "aws" {
  region = var.location
  default_tags {
    tags = {
      environment = "Terraform"
    }
  }
}

resource "aws_key_pair" "tf_keypair" {
  key_name   = "terraform_keypair"
  public_key = file(var.ssh_key_pub)
}

# Latest Ubuntu 20.04 Image
data "aws_ami" "tf_ami" {
  most_recent = true
  owners      = [var.image_publisher]

  filter {
    name   = "name"
    values = [var.image_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "tf_sg" {
  name = "terraform_securitygroup"

  # To Allow SSH and WireGuard Transport
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.wg_port
    to_port     = var.wg_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "tf_vm" {
  ami                         = data.aws_ami.tf_ami.id
  instance_type               = var.vm_size
  key_name                    = aws_key_pair.tf_keypair.key_name
  vpc_security_group_ids      = [aws_security_group.tf_sg.id]
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp2"
  }

  user_data = templatefile(
    var.init_script_template,
    {
      wg_client_pubkey = var.wg_client_pubkey,
      wg_psk           = var.wg_psk,
      admin_username   = var.admin_username,
      admin_ssh_pubkey = file(var.ssh_key_pub),
      ssh_port         = var.ssh_port,
      wg_port          = var.wg_port
  })

}

# Output
output "username" {
  value = var.admin_username
}
output "ip_address" {
  value = aws_instance.tf_vm.public_ip
}
output "ssh_port" {
  value = var.ssh_port
}
output "wg_port" {
  value = var.wg_port
}
