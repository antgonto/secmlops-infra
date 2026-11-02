# The laptop lab through OpenTofu: the vagrant provider runs `vagrant up/destroy` against the repo's
# Vagrantfile (two directories up), so OpenTofu owns the VM lifecycle while Vagrant/VirtualBox does the work.
terraform {
  required_version = ">= 1.8"
  required_providers {
    vagrant = {
      source  = "bmatcuk/vagrant"
      version = "~> 4.1"
    }
  }
}

provider "vagrant" {}

variable "vm_memory" {
  type    = string
  default = "16384"
}

variable "vm_cpus" {
  type    = string
  default = "6"
}

variable "lite" {
  type    = bool
  default = false
}

resource "vagrant_vm" "secmlops" {
  name            = "secmlops-lab"
  vagrantfile_dir = "../.."
  env = {
    SECMLOPS_VM_MEM  = var.vm_memory
    SECMLOPS_VM_CPUS = var.vm_cpus
    SECMLOPS_LITE    = var.lite ? "1" : "0"
  }
}

output "machine" {
  value = "vagrant status lab   # run from the repo root"
}
