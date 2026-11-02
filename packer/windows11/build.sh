#!/usr/bin/env bash
# Renders autounattend.xml with the product key from the git-ignored pkrvars (or PKR_VAR_product_key), builds, then scrubs the rendered file.
set -euo pipefail
cd "$(dirname "$0")"
KEY="${PKR_VAR_product_key:-$(grep -E '^product_key' windows11.auto.pkrvars.hcl 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/')}"
[ -n "$KEY" ] || { echo "product_key not set (windows11.auto.pkrvars.hcl or PKR_VAR_product_key)"; exit 1; }
sed "s|__PRODUCT_KEY__|$KEY|" autounattend.xml.tpl > autounattend.xml
trap 'rm -f autounattend.xml' EXIT          # the rendered file with the key never outlives the build
packer init .
packer build -force .
echo "box built: packer/windows11/output/windows11.box"
vagrant box add --force --name secmlops/windows11 output/windows11.box
