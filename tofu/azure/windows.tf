# ---------------------------------------------------------------------------------------------------
# OPTIONAL Windows 11 machine in production (enable_windows = true). Runs the Windows CI agents.
# Licensing: Azure's Windows 11 marketplace images require an eligible Windows 11 license
# (Microsoft 365 E3/E5, Windows E3/E5, or VDA). Setting enable_windows=true is your assertion that you have one.
# Configured by Ansible over WinRM from the Ubuntu VM — the same ansible/windows.yml as the laptop lab.
# ---------------------------------------------------------------------------------------------------
variable "enable_windows" {
  type    = bool
  default = false
}

variable "windows_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

resource "azurerm_network_interface" "win" {
  count               = var.enable_windows ? 1 : 0
  name                = "${var.prefix}-win-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.60.1.21"
  }
}

resource "azurerm_network_interface_security_group_association" "win" {
  count                     = var.enable_windows ? 1 : 0
  network_interface_id      = azurerm_network_interface.win[0].id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "win" {
  count                 = var.enable_windows ? 1 : 0
  name                  = "${var.prefix}-win11"
  computer_name         = "secmlops-win11"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.windows_vm_size
  admin_username        = "vagrant"
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.win[0].id]
  license_type          = "Windows_Client" # Azure Hybrid Benefit for eligible Windows 11 licenses
  custom_data           = base64encode(module.bootstrap.win_first_boot)

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = "<FirstLogonCommands><SynchronousCommand><CommandLine>powershell -ExecutionPolicy Bypass -Command \"Get-Content C:\\AzureData\\CustomData.bin | powershell -\"</CommandLine><Description>Enable WinRM</Description><Order>1</Order></SynchronousCommand></FirstLogonCommands>"
  }
}

output "windows_private_ip" {
  value = var.enable_windows ? "10.60.1.21" : "disabled"
}
