# tofu/ — one lab, four targets, one Ansible

| Directory | Creates | Provisioning | Public DNS |
|---|---|---|---|
| `local/`  | the laptop VM through Vagrant (VirtualBox / VMware)                 | Vagrant `ansible_local`            | /etc/hosts |
| `aws/`    | VPC, subnet, IGW, security group, EIP, EC2 (Ubuntu 24.04), Route 53 | `modules/lab-bootstrap` cloud-init | Route 53 zone |
| `gcp/`    | VPC, subnet, firewall, static IP, GCE (Ubuntu 24.04), Cloud DNS     | `modules/lab-bootstrap` cloud-init | Cloud DNS zone |
| `azure/`  | RG, VNet, NSG, public IP, VM (Ubuntu 24.04), Azure DNS; optional Windows 11 | `modules/lab-bootstrap` cloud-init | Azure DNS zone |

All four end with the identical lab: same roles, same tool pins, same 13-check smoke test. `scripts/replica-check.sh` proves it.

    make cloud-init CLOUD=aws && make cloud-apply CLOUD=aws && make cloud-log CLOUD=aws && make cloud-replica CLOUD=aws
