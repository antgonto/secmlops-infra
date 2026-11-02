Place your licensed Windows 11 ISO here as Win11.iso. This folder is git-ignored; the ISO and your product key are never committed.
Get the ISO from https://www.microsoft.com/software-download/windows11 ("Download Windows 11 Disk Image (ISO) for x64") and note the
SHA-256 Microsoft publishes on that page; put it in packer/windows11/windows11.auto.pkrvars.hcl as iso_checksum.
