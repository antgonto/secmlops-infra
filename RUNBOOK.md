# SecMLOps lab — execution runbook (step by step)

Follow in order. Every step names the command, what it does, how long it takes, and what you should see.
All hostnames are under `secmlops.com`. Total first-run time: ~45–60 min, mostly unattended.

## Host OS support

| Host | Provider | Guest arch | Notes |
|---|---|---|---|
| Ubuntu 22.04/24.04, Debian 12 | VirtualBox 7.x | amd64 | Primary path. `make` targets as documented |
| Windows 11 | VirtualBox 7.x | amd64 | Use `.\lab.ps1 <target>` from PowerShell instead of `make`. Disable Hyper-V (see Phase 0) |
| macOS Intel | VirtualBox 7.x | amd64 | Same as Ubuntu; `make` via Xcode CLT or Homebrew |
| macOS Apple Silicon (M1–M4) | VirtualBox 7.1+ **or** VMware Fusion (`--provider=vmware_desktop`) | **arm64** | Every tool has an arm64 build (verified); Harbor runs under amd64 emulation, installed automatically |

## Phase 0 — Laptop prerequisites (15 min, once)
1. Install VirtualBox 7.x, Vagrant 2.4.x, Git. Optional: OpenTofu 1.12.x, kubectl, helm, cosign, gh/glab/az.
   (Per-OS commands: Notion → Tool Installation → 1. Laptop toolkit.)
2. Enable hardware virtualization in BIOS/UEFI.
   **Windows 11:** VirtualBox and Hyper-V/WSL2 fight over the hypervisor. Either disable Hyper-V (`bcdedit /set hypervisorlaunchtype off`, reboot; re-enable later with `... auto`) or accept the slower Hyper-V-backed VirtualBox mode. Also: `winget install Oracle.VirtualBox Hashicorp.Vagrant Git.Git`, run everything from **PowerShell** (not WSL), and `git config --global core.autocrlf false` before unpacking so scripts keep LF endings.
   **Apple Silicon:** VirtualBox 7.1+ (arm64 build) from virtualbox.org, or VMware Fusion (free for personal use) + `vagrant plugin install vagrant-vmware-desktop`. Then `vagrant up --provider=vmware_desktop` if using Fusion.
3. Free resources: 16 GB RAM, 6 CPU, 120 GB disk for the VM.
4. `vagrant --version && VBoxManage --version` → both print a version.

## Phase 1 — Unpack and (optionally) size the VM (2 min)
    tar xzf secmlops-infra.tar.gz && cd secmlops-infra
    make help                                  # lists every target
Optional sizing (defaults 16 GB / 6 vCPU):
    export SECMLOPS_VM_MEM=24576 SECMLOPS_VM_CPUS=8

## Phase 2 — Build and provision the VM (20–30 min, unattended)
    make up                                    # = vagrant up      (Windows 11: .\lab.ps1 up)
What happens, in order (watch the Ansible role names scroll by):
  1. VirtualBox creates the Ubuntu 24.04 VM at 192.168.56.20, forwards ports 5000/7070/8080/8081/8200/3000/6443/6444.
  2. Play 1 `generate_secrets` writes random credentials to /opt/secmlops/.lab-secrets.yml (git-ignored, idempotent).
  3. Play 2 roles: common → docker → ci_tools → hosts_entries → compose_stacks → k3s_clusters → harbor → bootstrap → kyverno → azdo_agent
     - ci_tools is the longest (downloads ~15 binaries, pip packages, Nuclei templates, 4 images).
     - harbor downloads the v2.11.1 installer and waits for /api/v2.0/health.
     - bootstrap seeds OpenBao (secret/mlops/s3|harbor|cosign), creates S3 buckets, generates the Cosign keypair, creates the Harbor `mlops` project, writes CREDENTIALS.txt.
     - kyverno installs Kyverno and applies the admission policy with the real Cosign public key.
Expected last lines:
    PLAY RECAP ... failed=0
If it stops with failed=1: note the failing task name, fix (see Troubleshooting), then `make provision` — it resumes idempotently.

## Phase 3 — Hostnames on the laptop (1 min)
Append to /etc/hosts — `make hosts` prints the line and the path for your OS (Windows 11: `C:\Windows\System32\drivers\etc\hosts`, edit as Administrator; macOS/Ubuntu: `sudo nano /etc/hosts`):
    192.168.56.20 harbor.secmlops.com mlflow.secmlops.com s3.secmlops.com bao.secmlops.com secobserve.secmlops.com grafana.secmlops.com staging.secmlops.com apps.secmlops.com course.secmlops.com course-staging.secmlops.com
Check: `ping -c1 mlflow.secmlops.com` answers from 192.168.56.20.

## Phase 4 — Verify services and toolchain (2 min)
    make smoke
Expected: 13 `ok` lines and `passed=13 failed=0`:
  docker · core compose · S3 gateway · MLflow · OpenBao · SecObserve · Grafana · Prometheus · Harbor · k3s staging · k3s production · apps ns · infra ns
    make tools
Expected: every tool `ok` with a version and `present=N missing=0`; the runners block shows gitlab-runner, gh-runner, azdo-agent present.
    make creds
Prints /opt/secmlops/CREDENTIALS.txt: S3 keys, Harbor admin password, OpenBao root token, Grafana password, Cosign key location.

## Phase 5 — Confirm each service from the laptop (5 min)
    curl -s http://mlflow.secmlops.com:5000/health                     # OK
    curl -s http://bao.secmlops.com:8200/v1/sys/health | jq .initialized  # true
    curl -s -o /dev/null -w '%{http_code}\n' http://s3.secmlops.com:7070/  # 403 (auth required = alive)
    curl -s http://harbor.secmlops.com:8080/api/v2.0/health | jq .status   # healthy
    open http://grafana.secmlops.com:3000   (admin / password from make creds)
    open http://secobserve.secmlops.com:8081
Kubernetes from the laptop (copies the two kubeconfigs and rewrites the server address):
    vagrant ssh -c "sudo cat /etc/rancher/k3s/k3s.yaml"  | sed 's/127.0.0.1/192.168.56.20/' > ~/.kube/staging.yaml
    vagrant ssh -c "sudo cat /etc/rancher/k3s/prod.yaml" | sed 's/127.0.0.1/192.168.56.20/' > ~/.kube/prod.yaml
    KUBECONFIG=~/.kube/staging.yaml kubectl get nodes      # staging   Ready
    KUBECONFIG=~/.kube/prod.yaml    kubectl get nodes      # production Ready
    KUBECONFIG=~/.kube/staging.yaml kubectl get clusterpolicy   # verified-mlops-images  Ready=true
Merge them if you want named contexts `staging` / `production` (the labs use --context):
    KUBECONFIG=~/.kube/staging.yaml:~/.kube/prod.yaml kubectl config view --flatten > ~/.kube/config
    kubectl config rename-context default staging   # then repeat for the prod entry → production

## Phase 6 — Register the CI runners (5 min each; needs a token from each platform)
    make runners                                # prints the three commands
    make runner-github GH_REPO_URL=https://github.com/<you>/secmlops-demo GH_RUNNER_TOKEN=<token>
    make runner-gitlab GL_URL=https://gitlab.com GL_RUNNER_TOKEN=glrt-xxxx
    make agent AZDO_URL=https://dev.azure.com/<org> AZDO_PAT=<pat>
Verify: each platform's Runners/Agents page shows the VM online (labels `lab`). Revoke the ADO PAT afterwards.
Where each token comes from: Notion → Tool Installation → 3. The three platforms from zero.

## Phase 7 — First real job (2 min)
Push the smoke workflow from the platforms page (or run the project's PR pipeline). Expected: a green job whose log shows the VM hostname and `trivy --version` / `opengrep --version`.

## Phase 8 — Day-2 operations
    make provision      # re-run Ansible (idempotent) after changing a pin or template
    make down / make up # halt / resume (data persists under /data/secmlops)
    make destroy        # delete the VM — regenerates all secrets on the next make up
    make lint           # yamllint + ansible-lint before committing changes
    make tf-apply / make tf-destroy   # the OpenTofu path instead of vagrant

## Troubleshooting (first-boot issues we expect)
| Symptom | Where | Fix |
|---|---|---|
| `VT-x is not available` / VM won't start | Phase 2 | Enable virtualization in BIOS; Windows: disable Hyper-V |
| Ansible stalls in ci_tools for many minutes | Phase 2 | Nuclei template download on slow links — wait; it runs once |
| `harbor: wait for API health` times out | Phase 2 | `vagrant ssh -c "sudo docker compose -f /opt/secmlops/harbor/docker-compose.yml ps"`; usually still starting — `make provision` |
| A pinned download 404s | Phase 2 | Re-resolve the version in ansible/roles/ci_tools/defaults/main.yml (releases move); `make provision` |
| k3s production not Ready | Phase 4 | `vagrant ssh -c "sudo systemctl status k3s-prod"`; ports 6443/6444 must be free on the host |
| `make smoke` S3 shows 000 | Phase 4 | `docker compose -f /opt/secmlops/core/compose.yml logs s3` — check the data dir /data/secmlops/s3 is writable |
| Laptop can't resolve *.secmlops.com | Phase 3/5 | /etc/hosts line missing or a VPN overriding DNS |
| Docker push to Harbor fails: http: server gave HTTP response | Phase 7 | Add `"insecure-registries": ["harbor.secmlops.com:8080"]` to the laptop's Docker daemon.json (the VM already has it) |
| GitLab jobs can't reach *.secmlops.com | Phase 7 | The helper sets --docker-network-mode host; re-register if you registered by hand |
| GitHub runner token rejected | Phase 6 | Tokens expire in ~1 h — generate it last |

## What to capture on the first real run (for the dry-run report)
- Total wall time for `make up` and the slowest role.
- Any task that failed once and passed on `make provision`.
- The three `make smoke` / `make tools` outputs.
- Which troubleshooting rows were needed — they become fixes to the roles, not just notes.
