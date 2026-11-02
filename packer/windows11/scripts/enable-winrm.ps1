# Runs at first logon (from autounattend). Enables WinRM over HTTP on the private lab network so
# Packer, Vagrant and Ansible can manage the VM. Ansible later switches it to HTTPS.
Set-ExecutionPolicy -Scope LocalMachine RemoteSigned -Force
Enable-PSRemoting -Force -SkipNetworkProfileCheck
winrm quickconfig -q
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
netsh advfirewall firewall add rule name="WinRM HTTP" dir=in action=allow protocol=TCP localport=5985
Set-Service WinRM -StartupType Automatic; Restart-Service WinRM
