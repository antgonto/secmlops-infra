<# "Is my computer ready?" — Windows 11. Run in PowerShell BEFORE installing anything:  .\scripts\ready-check.ps1 #>
$fail = 0; $warn = 0
function Ok($n,$m){ "  ok    {0,-28} {1}" -f $n,$m }
function Warn($n,$m){ "  WARN  {0,-28} {1}" -f $n,$m; $script:warn++ }
function Fail($n,$m){ "  FAIL  {0,-28} {1}" -f $n,$m; $script:fail++ }
"== Operating system"
$os = Get-CimInstance Win32_OperatingSystem
if ($os.Caption -match "Windows 11") { Ok "OS" "$($os.Caption) build $($os.BuildNumber)" } else { Fail "OS" "$($os.Caption) — the course supports Windows 11" }
"== Memory (full lab 16 GB; lite 8 GB)"
$mem = [math]::Round($os.TotalVisibleMemorySize/1MB)
if ($mem -ge 24) { Ok "RAM" "$mem GB — full lab" } elseif ($mem -ge 16) { Warn "RAM" "$mem GB — use lite mode (`$env:SECMLOPS_LITE=1) or close everything else" } elseif ($mem -ge 12) { Warn "RAM" "$mem GB — lite mode only" } else { Fail "RAM" "$mem GB — below 12 GB; use the cloud lab (Part C)" }
"== CPU"
$cpus = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if ($cpus -ge 8) { Ok "CPU cores" $cpus } elseif ($cpus -ge 4) { Warn "CPU cores" "$cpus — full lab wants 6; lite uses 4" } else { Fail "CPU cores" "$cpus — need at least 4" }
"== Virtualization"
$ci = Get-ComputerInfo
if ($ci.HyperVRequirementVirtualizationFirmwareEnabled -or $ci.HyperVisorPresent) { Ok "VT-x/AMD-V" "enabled in firmware" } else { Fail "VT-x/AMD-V" "disabled — enable Virtualization in BIOS/UEFI" }
$hv = (bcdedit /enum '{current}' 2>$null | Select-String hypervisorlaunchtype)
if ($hv -and $hv -notmatch "Off") { Warn "Hyper-V" "hypervisorlaunchtype is not Off — VirtualBox will be slow; Module 0 explains bcdedit /set hypervisorlaunchtype off" } else { Ok "Hyper-V" "off (VirtualBox gets the CPU)" }
"== Disk (120 GB free for the full lab)"
$free = [math]::Round((Get-PSDrive -Name $HOME.Substring(0,1)).Free/1GB)
if ($free -ge 120) { Ok "Free disk on $($HOME.Substring(0,2))" "$free GB" } elseif ($free -ge 60) { Warn "Free disk" "$free GB — lite mode (60 GB) only" } else { Fail "Free disk" "$free GB — free up space" }
"== Admin rights"
if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Ok "Administrator" "this PowerShell is elevated" } else { Warn "Administrator" "not elevated — installs in Module 0 need 'Run as administrator'" }
"== Internet"
try { Invoke-WebRequest -Uri https://github.com -Method Head -TimeoutSec 8 | Out-Null; Ok "Reach github.com" "yes" } catch { Fail "Reach github.com" "no — check the connection or a proxy" }
"== Already installed? (fine if not — Module 0 installs them)"
foreach ($t in "git","vagrant","VBoxManage","tofu","packer") { if (Get-Command $t -ErrorAction SilentlyContinue) { Ok $t ((& $t --version 2>$null | Select-Object -First 1)) } else { "  --    {0,-28} not yet (Module 0/2)" -f $t } }
""
if ($fail -gt 0) { "RESULT: $fail problem(s) to fix before starting (see FAIL lines)."; exit 1 } elseif ($warn -gt 0) { "RESULT: ready, with $warn thing(s) to know (see WARN lines)." } else { "RESULT: ready for the full lab." }
