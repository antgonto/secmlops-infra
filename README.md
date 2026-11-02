# SecMLOps Lab Infrastructure

One Ubuntu 24.04 VM (VirtualBox) that runs the whole SecMLOps reference
architecture side by side: MLflow, VersityGW (S3), OpenBao, SecObserve, Harbor,
Prometheus/Grafana/Loki, and two k3s clusters (staging + production).

## Stack

- **OpenTofu** (`tofu/`) drives the VM lifecycle via the Vagrant provider — optional; you can also just `vagrant up`. (OpenTofu is the MPL-2.0 fork of Terraform, which moved to BSL in 2023.)
- **Vagrant** (`Vagrantfile`) defines the VM (16 GB / 6 vCPU / 120 GB) and runs Ansible on first boot.
- **Ansible** (`ansible/`) provisions everything: Docker, `/etc/hosts` entries, the compose stacks, k3s, and the Azure DevOps agent.
- **Docker Compose** (rendered by Ansible into `/opt/secmlops/`) runs the platform services.
- **k3s manifests** (`k3s/`) — default-deny network policy and the Kyverno admission policy.

## Storage note

All object storage is one **VersityGW** S3 endpoint (Apache-2.0) on the VM's local disk, serving the `mlflow`, `ml-data` (DVC), and `harbor` buckets. MinIO was dropped after its upstream repo was archived (April 2026). Ceph is deliberately **not** used: it is a multi-node distributed system (3-node minimum) and adds nothing on a single VM — it stays in the course only as the production reference for HA/petabyte scale.

## Licensing note

Vagrant is BSL-1.1 (source-available, fine for lab use). VirtualBox base is GPLv3; do **not** install the Extension Pack (PUEL) for commercial delivery. Grafana/Loki are AGPLv3.

## Host OS
Ubuntu · Windows 11 (`.\lab.ps1` instead of `make`) · macOS Intel · macOS Apple Silicon (arm64 guest; all tools have arm64 builds). See RUNBOOK.md.

## Quick start

    make up            # create the VM and provision it (~15-20 min first run)
    make smoke         # health-check every service
    make k3s-policies  # apply network policy + Kyverno to staging

Then add these to your host's /etc/hosts so the names resolve to the VM:

    192.168.56.20 harbor.secmlops.com mlflow.secmlops.com s3.secmlops.com bao.secmlops.com \
                  secobserve.secmlops.com grafana.secmlops.com staging.secmlops.com apps.secmlops.com course.secmlops.com course-staging.secmlops.com

## Manual post-steps (secrets — kept out of the image)

1. **Harbor**: run its online installer into `/opt/secmlops/harbor` (see runbook).
2. **Azure DevOps agent**: `sudo -u azagent AZDO_URL=... AZDO_PAT=... /opt/azagent/register-agent.sh`
3. **Kyverno key**: replace `REPLACE_WITH_COSIGN_PUB` in `k3s/kyverno-verified-images.yaml`.

## Teardown

    make destroy       # delete the VM
