# ===========================================================================================
# SecMLOps lab — PRODUCTION on Azure with OpenTofu.
# Same Ansible as the laptop lab: the VM clones this repo and runs `ansible-playbook site.yml`
# on itself via cloud-init (the exact equivalent of Vagrant's ansible_local).
#   tofu init && tofu apply     ~15 min for infra + ~30 min provisioning inside the VM
# ===========================================================================================
terraform {
  required_version = ">= 1.8"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "eastus"
}
variable "prefix" {
  type    = string
  default = "secmlops"
}
variable "vm_size" {
  type    = string
  default = "Standard_D8s_v5"
} # 8 vCPU / 32 GB — the lab needs 16 GB; headroom for two clusters
variable "admin_user" {
  type    = string
  default = "secmlops"
}
variable "ssh_public_key" {
  type        = string
  description = "Contents of your ~/.ssh/id_ed25519.pub"
}
variable "allowed_cidr" {
  type        = string
  description = "Your office/VPN egress CIDR — the ONLY source allowed to reach the lab (e.g. 203.0.113.0/24)"
}
variable "repo_url" {
  type        = string
  description = "Git URL of this infra repo (HTTPS, public or with a read token)"
}
variable "dns_zone" {
  type    = string
  default = "secmlops.com"
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.60.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "lab" {
  name                 = "lab"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.60.1.0/24"]
}

# Default deny; only your CIDR may reach SSH and the service ports. Production means no 0.0.0.0/0.
resource "azurerm_network_security_group" "lab" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  dynamic "security_rule" {
    for_each = {
      ssh      = { prio = 100, ports = "22", src = var.allowed_cidr }
      portal   = { prio = 110, ports = "80,443", src = "*" } # the course portal only (Course 3)
      services = { prio = 120, ports = "3000,5000,7070,8080,8081,8200,6443,6444", src = var.allowed_cidr }
    }
    content {
      name                       = security_rule.key
      priority                   = security_rule.value.prio
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = split(",", security_rule.value.ports)
      source_address_prefix      = security_rule.value.src
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_public_ip" "lab" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "lab" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.60.1.20"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}

resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

module "bootstrap" {
  source       = "../modules/lab-bootstrap"
  repo_url     = var.repo_url
  lab_ip       = "10.60.1.20"
  lab_domain   = var.dns_zone
  allowed_cidr = var.allowed_cidr
}

resource "azurerm_linux_virtual_machine" "lab" {
  name                  = "${var.prefix}-lab"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.vm_size
  admin_username        = var.admin_user
  network_interface_ids = [azurerm_network_interface.lab.id]
  custom_data           = base64encode(module.bootstrap.cloud_init)

  admin_ssh_key {
    username   = var.admin_user
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  identity {
    type = "SystemAssigned"
  } # lets the VM read Key Vault / Entra without stored credentials (Course 2 Ch. 2)
}

# Public DNS for the lab hostnames — replaces the laptop's /etc/hosts line in production.
resource "azurerm_dns_zone" "lab" {
  name                = var.dns_zone
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_dns_a_record" "services" {
  for_each            = toset(module.bootstrap.hostnames)
  name                = each.key
  zone_name           = azurerm_dns_zone.lab.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 300
  records             = [azurerm_public_ip.lab.ip_address]
}

output "public_ip" {
  value = azurerm_public_ip.lab.ip_address
}

output "ssh" {
  value = "ssh ${var.admin_user}@${azurerm_public_ip.lab.ip_address}"
}

output "name_servers" {
  value       = azurerm_dns_zone.lab.name_servers
  description = "Delegate secmlops.com (or a sub-zone) to these at GoDaddy"
}

output "provision_log" {
  value = "ssh in and: tail -f /var/log/secmlops-provision.log"
}
