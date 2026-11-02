# SecMLOps lab — two machines, one Vagrantfile.
#   lab    (primary, Ubuntu 24.04)  plain `vagrant up` / `make up` builds only this one
#   win11  (optional, SECMLOPS_WIN11=1) built from YOUR licensed ISO with packer/windows11; configured over WinRM from lab
# OpenTofu drives this via the vagrant provider (tofu/local); `vagrant up` directly also works.
Vagrant.configure("2") do |config|
  lite     = ENV["SECMLOPS_LITE"] == "1"
  vm_mem   = ENV.fetch("SECMLOPS_VM_MEM",  lite ? "8192" : "16384").to_i
  vm_cpus  = ENV.fetch("SECMLOPS_VM_CPUS", lite ? "4" : "6").to_i
  demo_dir = File.expand_path("../secmlops-demo", __dir__)

  config.vm.box_check_update = false

  # ---------------------------------------------------------------- lab (Ubuntu)
  config.vm.define "lab", primary: true do |lab|
    # bento publishes amd64 and arm64 builds; Vagrant picks the one matching the host CPU
    # (x86 hosts -> VirtualBox amd64; Apple Silicon -> VirtualBox 7.1+ arm64 or VMware Fusion).
    lab.vm.box      = "bento/ubuntu-24.04"
    lab.vm.hostname = "secmlops"

    # Private host-only network so the *.secmlops.com hostnames resolve to the VM.
    lab.vm.network "private_network", ip: "192.168.56.20"

    # Forward the service ports so the host browser can reach them.
    { "mlflow" => 5000, "harbor" => 8080, "s3" => 7070, "openbao" => 8200, "secobserve" => 8081,
      "grafana" => 3000, "k3s-staging" => 6443, "k3s-prod" => 6444 }.each do |name, port|
      lab.vm.network "forwarded_port", guest: port, host: port, id: name
    end

    # Share the student's project (if it sits next to this folder) so edit-on-laptop / run-on-VM needs no second clone.
    lab.vm.synced_folder demo_dir, "/home/vagrant/secmlops-demo", owner: "vagrant", group: "vagrant" if File.directory?(demo_dir)

    lab.vm.provider "virtualbox" do |vb|
      vb.name   = "secmlops-lab"
      vb.memory = vm_mem
      vb.cpus   = vm_cpus
      vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]   # k3s inside the VM
    end
    # Apple Silicon alternative: `vagrant up --provider=vmware_desktop` (VMware Fusion is free for personal use)
    lab.vm.provider "vmware_desktop" do |vw|
      vw.memory = vm_mem
      vw.cpus   = vm_cpus
      vw.vmx["ethernet1.virtualDev"] = "vmxnet3"
    end

    lab.vm.disk :disk, size: "120GB", primary: true if Vagrant.has_plugin?("vagrant-disksize")

    # Provision with Ansible running INSIDE the VM (ansible_local): no Ansible on the laptop, any laptop OS.
    lab.vm.provision "ansible_local" do |a|
      a.playbook           = "ansible/site.yml"
      a.galaxy_role_file   = "ansible/requirements.yml"
      a.compatibility_mode = "2.0"
      a.extra_vars         = { lite: lite }
    end
  end

  # ---------------------------------------------------------------- win11 (optional)
  if ENV["SECMLOPS_WIN11"] == "1"
    config.vm.define "win11", autostart: false do |w|
      w.vm.box          = "secmlops/windows11"
      w.vm.hostname     = "secmlops-win11"
      w.vm.communicator = "winrm"
      w.winrm.username  = "vagrant"
      w.winrm.password  = "vagrant"
      w.vm.guest        = :windows
      w.vm.network "private_network", ip: "192.168.56.21"
      w.vm.network "forwarded_port", guest: 3389, host: 33389, id: "rdp"
      w.vm.provider "virtualbox" do |vb|
        vb.name   = "secmlops-win11"
        vb.memory = ENV.fetch("SECMLOPS_WIN11_MEM", "8192").to_i
        vb.cpus   = ENV.fetch("SECMLOPS_WIN11_CPUS", "4").to_i
        vb.customize ["modifyvm", :id, "--tpm-type", "2.0"]
        vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
      end
      # No provisioner on purpose: `make provision-win` runs ansible/windows.yml FROM the lab VM over WinRM.
    end
  end
end
