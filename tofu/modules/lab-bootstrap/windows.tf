# First-boot PowerShell for the optional Windows machine on any cloud: enables WinRM on the private subnet
# so the Ubuntu VM can run ansible/windows.yml against it. Identical for AWS (Server 2025), GCP (Server 2025), Azure (Windows 11).
locals {
  win_first_boot = <<-PS
    Set-ExecutionPolicy -Scope LocalMachine RemoteSigned -Force
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    New-NetFirewallRule -DisplayName "WinRM HTTP (lab subnet)" -Direction Inbound -Protocol TCP -LocalPort 5985 -RemoteAddress 10.60.1.0/24 -Action Allow
    Set-Service WinRM -StartupType Automatic; Restart-Service WinRM
  PS
}

output "win_first_boot" {
  value = local.win_first_boot
}
