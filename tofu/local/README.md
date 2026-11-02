# OpenTofu → Vagrant → VirtualBox

OpenTofu (MPL-2.0 fork of Terraform) owns the VM lifecycle via the `bmatcuk/vagrant` provider.

    tofu init
    tofu apply -var vm_memory=16384 -var vm_cpus=6
    tofu destroy    # tears the VM down

Ansible provisioning runs automatically inside the VM (ansible_local) on first boot.
