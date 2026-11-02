<#
.SYNOPSIS  Windows 11 equivalent of the Makefile: .\lab.ps1 <target> [-Var value ...]
.EXAMPLE   .\lab.ps1 up ; .\lab.ps1 smoke ; .\lab.ps1 runner-github -GhRepoUrl https://github.com/you/secmlops-demo -GhRunnerToken XXXX
.NOTES     Run from PowerShell (not WSL): Vagrant on Windows must talk to VirtualBox natively.
#>
param(
  [Parameter(Position=0)][ValidateSet("help","ready","up-lite","up","provision","smoke","tools","creds","down","destroy","status","ssh","runners","runner-github","runner-gitlab","agent","win-box","up-win","provision-win","win-agent","win-runner-github","down-win","cloud-init","cloud-plan","cloud-apply","cloud-ssh","cloud-log","cloud-destroy")]
  [string]$Target = "help",
  [ValidateSet("aws","gcp","azure")][string]$Cloud = "azure",
  [string]$GhRepoUrl, [string]$GhRunnerToken, [string]$GlUrl = "https://gitlab.com", [string]$GlRunnerToken, [string]$AzdoUrl, [string]$AzdoPat
)
$ErrorActionPreference = "Stop"
function Need($cmd) { if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "$cmd not found. See Course 1 -> Tool Installation -> Windows 11." } }
Need vagrant; Need VBoxManage
switch ($Target) {
  "help"      { Get-Content $PSCommandPath | Select-String -Pattern '^\s+"[a-z-]+"\s+\{' | ForEach-Object { $_.Line.Trim() } }
  "ready"     { & "$PSScriptRoot\scripts\ready-check.ps1" }
  "up-lite"   { $env:SECMLOPS_LITE = "1"; vagrant up }
  "up"        { vagrant up }
  "provision" { vagrant provision }
  "smoke"     { vagrant ssh -c "sudo /vagrant/scripts/smoke.sh" }
  "tools"     { vagrant ssh -c "tools-check --runner" }
  "creds"     { vagrant ssh -c "sudo cat /opt/secmlops/CREDENTIALS.txt" }
  "down"      { vagrant halt }
  "destroy"   { vagrant destroy -f }
  "status"    { vagrant status }
  "ssh"       { vagrant ssh }
  "runners"   { Write-Host ".\lab.ps1 runner-github -GhRepoUrl ... -GhRunnerToken ..."; Write-Host ".\lab.ps1 runner-gitlab -GlRunnerToken glrt-..."; Write-Host ".\lab.ps1 agent -AzdoUrl https://dev.azure.com/<org> -AzdoPat ..." }
  "runner-github" { if (-not $GhRepoUrl -or -not $GhRunnerToken) { throw "-GhRepoUrl and -GhRunnerToken required" }
                    vagrant ssh -c "sudo GH_REPO_URL='$GhRepoUrl' GH_RUNNER_TOKEN='$GhRunnerToken' /opt/register-github-runner.sh" }
  "runner-gitlab" { if (-not $GlRunnerToken) { throw "-GlRunnerToken required" }
                    vagrant ssh -c "sudo GL_URL='$GlUrl' GL_RUNNER_TOKEN='$GlRunnerToken' /opt/register-gitlab-runner.sh" }
  "cloud-init"    { Push-Location tofu\$Cloud; tofu init; Pop-Location }
  "cloud-plan"    { Push-Location tofu\$Cloud; tofu plan; Pop-Location }
  "cloud-apply"   { Push-Location tofu\$Cloud; tofu apply; Pop-Location }
  "cloud-ssh"     { Push-Location tofu\$Cloud; Invoke-Expression (tofu output -raw ssh); Pop-Location }
  "cloud-log"     { Push-Location tofu\$Cloud; Invoke-Expression ((tofu output -raw ssh) + " -t 'tail -f /var/log/secmlops-provision.log'"); Pop-Location }
  "cloud-destroy" { Push-Location tofu\$Cloud; tofu destroy; Pop-Location }
  "win-box"       { & "$PSScriptRoot\packer\windows11\build.ps1" }
  "up-win"        { $env:SECMLOPS_WIN11 = "1"; vagrant up win11 }
  "provision-win" { vagrant ssh lab -c "cd /vagrant/ansible && ansible-galaxy collection install -r requirements.yml -p ~/.ansible/collections >/dev/null && ansible-playbook -i windows.ini windows.yml" }
  "win-agent"     { if (-not $AzdoUrl -or -not $AzdoPat) { throw "-AzdoUrl and -AzdoPat required" }
                    $env:SECMLOPS_WIN11 = "1"; vagrant winrm win11 -c "C:\agents\register-azdo.ps1 -Url '$AzdoUrl' -Pat '$AzdoPat'" }
  "win-runner-github" { if (-not $GhRepoUrl -or -not $GhRunnerToken) { throw "-GhRepoUrl and -GhRunnerToken required" }
                    $env:SECMLOPS_WIN11 = "1"; vagrant winrm win11 -c "C:\agents\register-github.ps1 -RepoUrl '$GhRepoUrl' -Token '$GhRunnerToken'" }
  "down-win"      { $env:SECMLOPS_WIN11 = "1"; vagrant halt win11 }
  "agent"     { if (-not $AzdoUrl -or -not $AzdoPat) { throw "-AzdoUrl and -AzdoPat required" }
                vagrant ssh -c "sudo -u azagent AZDO_URL='$AzdoUrl' AZDO_PAT='$AzdoPat' /opt/azagent/register-agent.sh" }
}
