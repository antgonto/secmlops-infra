# Builds a Vagrant box "secmlops/windows11" from YOUR licensed Windows 11 ISO.
#   1. Put the ISO at  ~/secmlops/iso/Win11.iso   (Windows: C:\Users\<you>\secmlops\iso\Win11.iso)
#   2. Copy windows11.auto.pkrvars.hcl.example -> windows11.auto.pkrvars.hcl and fill in iso_path, iso_checksum, product_key
#   3. make win-box   (Windows: .\lab.ps1 win-box)      ~30-45 min; produces output/windows11.box
# Nothing licensed is ever committed: the ISO stays in iso/ (git-ignored) and the key lives only in the .auto.pkrvars.hcl file (git-ignored).
packer {
  required_plugins {
    virtualbox = { source = "github.com/hashicorp/virtualbox", version = ">= 1.1.0" }
    vagrant    = { source = "github.com/hashicorp/vagrant",    version = ">= 1.1.0" }
  }
}

variable "iso_path"     { type = string  description = "Path to the licensed Windows 11 ISO (never committed)" }
variable "iso_checksum" { type = string  description = "sha256:<hash> of the ISO — verify against Microsoft's published hash" }
variable "product_key"  { type = string  sensitive = true  description = "Your Windows 11 product key; from the git-ignored pkrvars file or the env var PKR_VAR_product_key" }
variable "vm_memory"    { type = number  default = 8192 }
variable "vm_cpus"      { type = number  default = 4 }
variable "disk_size"    { type = number  default = 81920 }
variable "admin_user"   { type = string  default = "vagrant" }
variable "admin_pass"   { type = string  default = "vagrant"  sensitive = true }   # lab default; rotated by Ansible on first provision

source "virtualbox-iso" "win11" {
  iso_url          = var.iso_path
  iso_checksum     = var.iso_checksum
  guest_os_type    = "Windows11_64"
  vm_name          = "secmlops-win11-build"
  memory           = var.vm_memory
  cpus             = var.vm_cpus
  disk_size        = var.disk_size
  firmware         = "efi"                    # Windows 11 requires UEFI + TPM + Secure Boot
  headless         = true
  communicator     = "winrm"
  winrm_username   = var.admin_user
  winrm_password   = var.admin_pass
  winrm_timeout    = "4h"                     # the unattended install runs inside this window
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  floppy_files     = []
  cd_files         = ["./autounattend.xml", "./scripts/enable-winrm.ps1", "./scripts/install-updates.ps1"]
  cd_label         = "cidata"
  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--tpm-type", "2.0"],
    ["modifyvm", "{{ .Name }}", "--nested-hw-virt", "on"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
  ]
  boot_wait        = "3s"
  boot_command     = ["<spacebar><wait><spacebar>"]         # answers "Press any key to boot from CD or DVD"
}

build {
  sources = ["source.virtualbox-iso.win11"]

  provisioner "powershell" {
    inline = [
      "Write-Host 'Windows 11 build: base image ready; WinRM enabled by autounattend.'",
      "Set-ExecutionPolicy -Scope LocalMachine RemoteSigned -Force",
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact = false
    output              = "output/windows11.box"
    vagrantfile_template = "Vagrantfile.template"
  }
}
