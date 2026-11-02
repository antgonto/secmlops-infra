#!/usr/bin/env bash
# "Is my computer ready?" — run BEFORE installing anything. Ubuntu / macOS. (Windows: ready-check.ps1)
# Prints one line per requirement with ok / WARN / FAIL and what to do. Exit 1 if any FAIL.
set -u
fail=0; warn=0
ok()   { printf '  ok    %-28s %s\n' "$1" "$2"; }
warnf(){ printf '  WARN  %-28s %s\n' "$1" "$2"; warn=$((warn+1)); }
failf(){ printf '  FAIL  %-28s %s\n' "$1" "$2"; fail=$((fail+1)); }
OS=$(uname -s); ARCH=$(uname -m)
echo "== Operating system"
case "$OS" in
  Linux)  . /etc/os-release 2>/dev/null; ok "OS" "$PRETTY_NAME ($ARCH)";;
  Darwin) ok "OS" "macOS $(sw_vers -productVersion) ($ARCH) — $([ "$ARCH" = arm64 ] && echo 'Apple Silicon: use VirtualBox 7.1+ arm64 or VMware Fusion' || echo 'Intel: VirtualBox 7.x')";;
  *)      failf "OS" "$OS is not supported; use Ubuntu, macOS, or Windows 11";;
esac
echo "== Memory (the lab VM needs 16 GB; lite mode needs 8 GB)"
if [ "$OS" = Linux ]; then MEM=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo); else MEM=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )); fi
if   [ "$MEM" -ge 24 ]; then ok "RAM" "${MEM} GB — full lab";
elif [ "$MEM" -ge 16 ]; then warnf "RAM" "${MEM} GB — use lite mode (SECMLOPS_LITE=1) or close everything else";
elif [ "$MEM" -ge 12 ]; then warnf "RAM" "${MEM} GB — lite mode only";
else failf "RAM" "${MEM} GB — below the 12 GB minimum; use the cloud lab (Part C) instead"; fi
echo "== CPU"
if [ "$OS" = Linux ]; then CPUS=$(nproc); else CPUS=$(sysctl -n hw.ncpu); fi
[ "$CPUS" -ge 8 ] && ok "CPU cores" "$CPUS" || { [ "$CPUS" -ge 4 ] && warnf "CPU cores" "$CPUS — full lab wants 6; lite mode uses 4" || failf "CPU cores" "$CPUS — need at least 4"; }
echo "== Virtualization"
if [ "$OS" = Linux ]; then
  if grep -qE 'vmx|svm' /proc/cpuinfo; then ok "VT-x/AMD-V" "present"; else failf "VT-x/AMD-V" "not visible — enable Virtualization in BIOS/UEFI"; fi
  [ -e /dev/kvm ] && [ -w /dev/kvm ] && warnf "KVM in use?" "/dev/kvm exists — close GNOME Boxes/virt-manager VMs before vagrant up" || true
else
  [ "$(sysctl -n kern.hv_support 2>/dev/null)" = 1 ] && ok "Hypervisor support" "present" || failf "Hypervisor support" "kern.hv_support=0"
fi
echo "== Disk (the lab needs 120 GB free)"
FREE=$(df -Pk "$HOME" | awk 'NR==2{printf "%d", $4/1024/1024}')
[ "$FREE" -ge 120 ] && ok "Free disk in \$HOME" "${FREE} GB" || { [ "$FREE" -ge 60 ] && warnf "Free disk in \$HOME" "${FREE} GB — lite mode (60 GB) only" || failf "Free disk in \$HOME" "${FREE} GB — free up space"; }
echo "== Admin rights"
if [ "$OS" = Linux ]; then sudo -n true 2>/dev/null && ok "sudo" "works without password prompt" || { groups | grep -qE 'sudo|wheel|admin' && ok "sudo" "you are in the sudo group (you'll be asked for your password)" || failf "sudo" "you're not an administrator on this machine"; }
else groups | grep -q admin && ok "admin" "you are an administrator" || failf "admin" "not an administrator on this Mac"; fi
echo "== Internet"
curl -sI --max-time 8 https://github.com >/dev/null && ok "Reach github.com" "yes" || failf "Reach github.com" "no — check the connection or a proxy"
echo "== Already installed? (fine if not — Module 0 installs them)"
for t in git vagrant VBoxManage tofu packer; do command -v $t >/dev/null 2>&1 && ok "$t" "$($t --version 2>/dev/null | head -1)" || printf '  --    %-28s not yet (Module 0/2)\n' "$t"; done
echo; if [ "$fail" -gt 0 ]; then echo "RESULT: $fail problem(s) to fix before starting (see FAIL lines)."; exit 1
elif [ "$warn" -gt 0 ]; then echo "RESULT: ready, with $warn thing(s) to know (see WARN lines)."; else echo "RESULT: ready for the full lab."; fi
