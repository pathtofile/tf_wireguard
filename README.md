# TF-Wireguard
Simple Terraform Scripts to setup a WireGuard server on various cloud providers.

- [TF-Wireguard](#tf-wireguard)
- [Overview](#overview)
- [Client Setup](#client-setup)
- [Variables](#variables)
  - [All providers:](#all-providers)
  - [AWS](#aws)
  - [Azure](#azure)
  - [Digital Ocean](#digital-ocean)
  - [OCI (Oracle Cloud)](#oci-oracle-cloud)
  - [Vultr](#vultr)
- [Running](#running)
  - [Deploy Server](#deploy-server)
  - [Start local client](#start-local-client)
  - [Alternate client: Vagrant](#alternate-client-vagrant)
- [Cleanup](#cleanup)
- [Why?](#why)
  - [Why should I use this?](#why-should-i-use-this)
  - [Why use this over a commercial VPN provider](#why-use-this-over-a-commercial-vpn-provider)
- [Why use this of Algo?](#why-use-this-of-algo)
- [Alternate Use - Single VMs](#alternate-use---single-vms)

# Overview
Terraform will provision
- A small Ubuntu 20.04 VM
- A new admin user
- An SSH keypair for new admin user
- Configure SSH server to only allow 
- Install and configure WireGuard server
- Generate new wireguard server keys and output public key
- Use cloud provider to only allow network connections to SSH, Wireguard, and ICMP.

# Client Setup
Before starting the server, install Wireguard on your client and create both client keys and a pre-shared key.
On Ubuntu Linux this is done as `root` by:
```bash
# Install Wireguard and resolvconf
apt install wireguard resolvconf

# Generate private and public keys
wg genkey | tee /etc/wireguard/private.key
cat /etc/wireguard/private.key | wg pubkey | tee /etc/wireguard/public.key

# Generate PSK
wg genpsk | tee /etc/wireguard/psk.key

# Restrict access to files
chmod go= /etc/wireguard/*.key
```

On Windows we can jsut use the current directory, however MAKE SURE to prevent
unauthorised users from accessing the folder:
```powershell
# Generate private and public keys
wg genkey | Out-File private.key -NoNewline
Get-Content .\private.key | wg pubkey | Out-File public.key -NoNewline

# Generate PSK
wg genpsk | Out-File psk.key -NoNewline
```

# Variables
Set the following variables, either using a [.tfvars](https://www.terraform.io/language/values/variables#variable-definitions-tfvars-files)
file, using `TF_VAR_xxx` environment variables, or manually editing the defaults in the `.tf` files:

## All providers:
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `admin_username`  | New admin user to create  | ubuntu |
| `ssh_key_pub`  | Local path the SSH public key to deploy and use  | ~/.ssh/id_rsa.pub |
| `ssh_port`  | TCP Port SSH server will listen on  | 22 |
| `wg_port`  | UDP Port WireGuard server will listen on  | 51820 |
| `wg_client_pubkey`  | The Client's WireGuard `public.key` | |
| `wg_psk`  | The Client's WireGuard `psk.key` | |
| `init_script_template` | The `cloud-init` script to run | [cloud_init.yml.tftpl](cloud_init.yml.tftpl) |
| `extra_open_ports` | A list of any extra TCP ports to open | empty list, i.e. no other port |
| `enable_ssh_access` | If true, interactive SSH access will be enabled for the admin user | False |
| `wg_server_prikey`  | Optional, use static private key for Wireguard server. Otherwise auto-generate a new key | |

## AWS
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `location`  | Region to deploy VM to | us-west-1
| `vm_size`  | Size of VM  | t2.micro
| `image_publisher`  | Used to select Linux Disto, see [aws.tf](./aws/aws.tf) for example | Canonical's ID
| `image_name`  | Used to select Linux Disto, see [aws.tf](./aws/aws.tf) for example | Ubuntu 20.04

## Azure
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `location`  | Region to deploy VM to | australiaeast
| `vm_size`  | Size of VM  | Standard_A1_v2
| `image_publisher`  | Used to select Linux Disto, see [azure.tf](./azure/azure.tf) for example | Canonical
| `image_name`  | Used to select Linux Disto, see [azure.tf](./azure/azure.tf) for example | Ubuntu Server
| `image_version`  | Used to select Linux Disto, see [azure.tf](./azure/azure.tf) for example | 20.04 LTS

## Digital Ocean
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `api_key`  | DigitalOcean API token |
| `location`  | Region to deploy VM to | sfo3
| `vm_size`  | Size of VM  | s-1vcpu-1gb
| `image_name`  | Used to select Linux Disto | ubuntu-20-04-x64

## OCI (Oracle Cloud)
*NOTE* Usuing default OCI shape is valid for the always-free tier.
For the API values see [these guides](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/tf-provider/01-summary.htm)
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `location`  | Region to deploy VM to | ap-sydney-1
| `vm_size`  | Size of VM  | VM.Standard.E2.1.Micro
| `image_name`  | Used to select Linux Disto | Canonical Ubuntu
| `image_version`  | Used to select Linux Disto | 20.04

Additionally set the variable `api_key` to a dictionary with these values:
| Variable Name  | Description
| ------------- | -------------
| `tenancy_ocid`  | tenancy OCID for API
| `user_ocid`  | tenancy OCID for API
| `api_fingerprint`  | API key fingerprint
| `api_key_pri`  | Path to API private key

e.g.:
```terraform
api_key = {
    tenancy_ocid    = "ocid1.tenancy.aaaaa"
    user_ocid       = "ocid1.user.oc1aaaaa"
    api_fingerprint = "64:04:63:...."
    api_key_pri     = "C:\\Users\\..."
}
```

## Vultr
| Variable Name  | Description | Default value |
| ------------- | ------------- | ------------- |
| `api_key`  | API Key |
| `image_name`  | Used to select Linux Disto | Ubuntu 20.04 x64
| `region`  | Region to deploy VM to | sjc
| `vm_size`  | Size of VM  | vc2-1c-1gb

If using a `.tfvars` file, a basic file looks like this:
```ini
# Global
admin_username = "path"
ssh_key_pub = "~/.ssh/cloud.pub"
ssh_port = 2222
wg_port = 5555
wg_client_pubkey = "aaaaaaa"
wg_psk = "aaaaa"

# AWS
location = "us-west-1"
```


# Running
## Deploy Server
Set variables according to above, then open `main.tf`, and set the `source` line in the module
to match the name of the cloud provider you wish the deploy to. e.g. to use Azure:
```terraform
module "mod" {
  source = "./azure"
  # ....
}
# ....
```

To deplopy to AWS, you also have to set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables
with you access key.

To deploy to Azure, you first have to run `az login` to login to Azure.

e.g. for AWS:
```powershell
# Set variables
$Env:AWS_ACCESS_KEY_ID = "..."
$Env:TF_VAR_xxx = "..."

# Run:
terraform init
terraform plan -out test.apply.tfplan
terraform apply test.apply.tfplan

# OR set a specific '.tfvars' file:
terraform plan -var-file="../vars.tfvars" -out test.apply.tfplan
terraform apply test.apply.tfplan

# OR in a single line
terraform apply -auto-approve
```

## Start local client
Once Terraform has run, the output with display information about the Server's IP.
You can now use the [helper Python script](generate_config.py) generate the WireGard config for the client.
This invlovles ssh'ing onto the WireGuard machine, waiting for cloud-init to finish
setting up the box, then retrieving the Server's publick key. This can take from 1-10minutes,
and sometimes the admin user isn't created straight away, and the first ssh attempt may fail.
But just keep trying.

On Linux:
```bash
# Select the private ssh key that corresponds to
# the 'ssh_key_pub' used to create the wireguard server
python generate_config.py --ssh-key ~/.ssh/id_rsa > /etc/wireguard/wg0.conf

# If not already running as root, do:
sudo -E bash -c 'python3 generate_config.py --ssh-key ~/.ssh/id_rsa > /etc/wireguard/wg0.conf'

# You can also specify the Dynamic DNS name to put in the config
# instead of the IP Address
python generate_config.py --ssh-key ~/.ssh/id_rsa --ddns-hostname wg.example.com > /etc/wireguard/wg0.conf

# Lock down config as it contains private keys
sudo chmod go= /etc/wireguard/wg0.conf

# Start Wireguard, output should show bytes sent and recieved
sudo wg-quick up wg0
sudo wg

# Test connectivity, Output should show server's IP
curl ipv4.icanhazip.com
ip route get 1.1.1.1
```

On Windows, outpuit the config to a `.conf` file, then in the WireGuard UI select
`Import tunnel from file` and select the generated config file:
```powershell
python generate_config.py --ssh-key C:\Users\username\.ssh\id_rsa > wg0.conf

# You can also specify the Dynamic DNS name to put in the config
# instead of the IP Address
python generate_config.py --ssh-key C:\Users\username\.ssh\id_rsa--ddns-hostname wg.example.com > wg0.conf
```

## Alternate client: Vagrant
Sometime you don't want to tunnell all your traffic through WireGuard,
you just want a quick dev environment that is tunneled. You could ssh
into the wireguard server and work on there, but these boxes are very low-specced,
so you might struggle to do real work on them. And increasing their performance 
increases the running costs.

This repo comes with a basic Vagrant Script to quickly spin a Ubuntu
VM, and install and setup WireGuard in it:
```bash
# First Use terraform to create the WG server
terraform apply -auto-approve

# Then generate the config file, but save it to the root directory
python3 generate_config.py aws ~/.ssh/id_rsa > wg0.conf

# Now use Vagrant to create the local vm
cd vagrant
vagrant up

# Connect to the local vm and test everything is working
vagrant ssh
curl ipv4.icanhazip.com
```

# Cleanup
To shutdown server, just use terraform:
```bash
terraform destroy -auto-approve
```

On Client, delete config and keys
```bash
# Stop Wireguard
wg-quick down wg0
cd /etc/wireguard/
rm wg0.conf psk.key private.key public.key
```

To cleanup Vagrant VM:
```bash
vagrant destroy --force
```

# Why?
## Why should I use this?
This is 99% just for myself, however I have made it public in case it is useful to others.
I have found creating this project useful to demonstrate:
- How to automatically create a basic '1 VM with SSH access' setup on the various cloud providers
- How to simply and automatically create a basic wireguard tunnel between two machines

## Why use this over a commercial VPN provider
For me, I like having more control over the endpoint my traffic comes out of.

# Why use this of Algo?
You probably shouldn't. [Algo](https://github.com/trailofbits/algo/) is an awesome project that does so much more than this,
includinf QR Codes for mobile devices, enabling IKEv2, deployment options for more cloud providers, etc.

For my personal use, however, I found it to do a little *too* much, and digging into the code to understand exactly what it
does was difficult at times. I wanted to create a project that I could understand how it worked, and did the minimal amount
to create a secure-enough temporary VPN endpoint.

# Alternate Use - Single VMs
I also use this project to quickly spin up a basic single VM on verious cloud providers and regions.

To do this, I use a tf variable file like this, to create a VM or a specific type, and use a different cloud-init that
only sets up the admin acccount, and not any firewall or wireguard configs:
```conf
# Basic info
admin_username       = "test"
ssh_key_pub          = "~/.ssh/cloud.pub"
ssh_port             = 22
location             = "us-west-1"
init_script_template = "cloud_init_basic.yml.tftpl"

# Select Image
## Ubuntu:
# image_publisher = "679593333241"
# image_name      = "ubuntu-minimal/images/hvm-ssd/ubuntu-focal-20.04-amd64-*"
# image_version   = null

## Amazon Linux:
# image_publisher = "137112412989"
# image_name      = "amzn2-ami-hvm-*-x86_64-gp2"
# image_version   = null

## Centos:
# image_publisher = "679593333241"
# image_name      = "CentOS-8*x86_64*"
# image_version   = null

# These get ignored
wg_client_pubkey = "aaaa"
wg_psk           = "aaaa"
```
