# ===========================================================================================
# Shared by aws/, gcp/, azure/: the cloud-init that turns a fresh Ubuntu 24.04 VM into the lab.
# It is the cloud equivalent of Vagrant's `ansible_local` provisioner — identical playbook,
# identical roles, so the three cloud labs and the laptop lab are replicas by construction.
# ===========================================================================================
variable "repo_url" {
  type        = string
  description = "Git URL of the secmlops-infra repo the VM clones (HTTPS; public or with a read token)"
}

variable "repo_ref" {
  type    = string
  default = "main"
}

variable "lab_ip" {
  type        = string
  description = "The VM's private IP (rendered into /etc/hosts and service configs)"
}

variable "lab_domain" {
  type    = string
  default = "secmlops.com"
}

variable "allowed_cidr" {
  type        = string
  description = "Passed to the hardening role for ufw"
}

locals {
  cloud_init = <<-CLOUD
    #cloud-config
    package_update: true
    packages: [git, python3-pip, python3-venv, jq]
    write_files:
      - path: /etc/secmlops-cloud.env
        permissions: "0644"
        content: |
          SECMLOPS_TARGET=cloud
          SECMLOPS_LAB_IP=${var.lab_ip}
          SECMLOPS_LAB_DOMAIN=${var.lab_domain}
    runcmd:
      - pip3 install --break-system-packages "ansible-core>=2.17" pywinrm
      - git clone --branch ${var.repo_ref} ${var.repo_url} /opt/secmlops-infra
      - cd /opt/secmlops-infra/ansible && ansible-galaxy collection install -r requirements.yml -p /root/.ansible/collections
      - >
        cd /opt/secmlops-infra/ansible && ANSIBLE_ROLES_PATH=roles ansible-playbook -i "localhost," -c local site.yml
        -e lab_ip=${var.lab_ip} -e lab_domain=${var.lab_domain} -e production=true -e allowed_cidr=${var.allowed_cidr}
        2>&1 | tee /var/log/secmlops-provision.log
      - ln -sf /opt/secmlops-infra /vagrant
      - /opt/secmlops-infra/scripts/smoke.sh > /var/log/secmlops-smoke.log 2>&1 || true
    final_message: "SecMLOps lab provisioned after $UPTIME seconds; see /var/log/secmlops-provision.log"
    CLOUD
}

output "cloud_init" {
  value = local.cloud_init
}

output "hostnames" {
  value = ["harbor", "mlflow", "s3", "bao", "secobserve", "grafana", "staging", "apps", "course", "course-staging"]
}

output "service_ports" {
  description = "Allow-listed to allowed_cidr: SSH, the lab tools, and the two clusters"
  value       = [22, 3000, 5000, 7070, 8080, 8081, 8200, 6443, 6444]
}

output "public_ports" {
  description = "Open to the internet: only the Course 3 portal (Caddy in the production cluster, hostPort 80/443); the portal has its own authentication"
  value       = [80, 443]
}
