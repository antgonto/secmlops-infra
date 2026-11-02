# Windows 11 host equivalent of build.sh
$ErrorActionPreference = "Stop"; Set-Location $PSScriptRoot
$key = $env:PKR_VAR_product_key
if (-not $key -and (Test-Path windows11.auto.pkrvars.hcl)) { $key = (Select-String -Path windows11.auto.pkrvars.hcl -Pattern '^product_key\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value }
if (-not $key) { throw "product_key not set (windows11.auto.pkrvars.hcl or PKR_VAR_product_key)" }
try {
  (Get-Content autounattend.xml.tpl -Raw) -replace '__PRODUCT_KEY__', $key | Set-Content -Encoding utf8 autounattend.xml
  packer init .; packer build -force .
  vagrant box add --force --name secmlops/windows11 output/windows11.box
} finally { Remove-Item -Force autounattend.xml -ErrorAction SilentlyContinue }
