output "vm_name" {
  value       = vagrant_vm.secmlops.name
  description = "Name of the provisioned lab VM"
}

output "vm_ip" {
  value       = "192.168.56.20"
  description = "Host-only IP; add *.secmlops.com entries for this in /etc/hosts"
}
