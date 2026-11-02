# SecMLOps lab — one-command lifecycle.
# Host needs: VirtualBox, Vagrant. (OpenTofu optional, for tf-* targets.)

.PHONY: help up provision down destroy tf-apply tf-destroy creds smoke agent lint

help:
	@echo "SecMLOps lab:"
	@echo "  make up         - create the VM + provision EVERYTHING (one command)"
	@echo "  make smoke      - health-check every service"
	@echo "  make tools      - verify every CLI/scanner on the runner host"
	@echo "  make runners    - how to register the GitHub / GitLab / Azure runners"
	@echo "  make creds      - print the generated lab credentials"
	@echo "  make agent      - register the Azure DevOps agent (needs AZDO_URL, AZDO_PAT)"
	@echo "  make provision  - re-run Ansible on the running VM"
	@echo "  make down       - halt the VM   |   make destroy - delete it"
	@echo "  make tf-apply   - drive the VM via OpenTofu instead of vagrant"
	@echo "  make lint       - lint Ansible + YAML"

up:
	vagrant up

provision:
	vagrant provision

down:
	vagrant halt

destroy:
	vagrant destroy -f

tf-apply:   ## create + provision the VM through OpenTofu (same as make up)
	cd tofu/local && tofu init -input=false >/dev/null && tofu apply

tf-destroy: ## delete the VM through OpenTofu
	cd tofu/local && tofu destroy

creds:
	vagrant ssh -c "sudo cat /opt/secmlops/CREDENTIALS.txt"

ssh:        ## shell into the lab VM
	vagrant ssh lab

smoke:
	vagrant ssh -c "/vagrant/scripts/smoke.sh"

tools:
	vagrant ssh -c "tools-check --runner"

runners:
	@echo "GitHub:  make runner-github GH_REPO_URL=... GH_RUNNER_TOKEN=..."
	@echo "GitLab:  make runner-gitlab GL_URL=... GL_RUNNER_TOKEN=..."
	@echo "Azure:   make agent AZDO_URL=... AZDO_PAT=..."

runner-github:
	vagrant ssh -c "sudo GH_REPO_URL='$(GH_REPO_URL)' GH_RUNNER_TOKEN='$(GH_RUNNER_TOKEN)' /opt/register-github-runner.sh"

runner-gitlab:
	vagrant ssh -c "sudo GL_URL='$(GL_URL)' GL_RUNNER_TOKEN='$(GL_RUNNER_TOKEN)' /opt/register-gitlab-runner.sh"

agent:
	@test -n "$(AZDO_URL)" || (echo "set AZDO_URL=..." && exit 1)
	@test -n "$(AZDO_PAT)" || (echo "set AZDO_PAT=..." && exit 1)
	vagrant ssh -c "sudo -u azagent AZDO_URL='$(AZDO_URL)' AZDO_PAT='$(AZDO_PAT)' /opt/azagent/register-agent.sh"

lint:
	cd ansible && yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" . && \
	  ansible-lint site.yml || true

ready:      ## is this laptop ready? (RAM, CPU, virtualization, disk, admin, internet)
	scripts/ready-check.sh
up-lite:    ## build the lab in LITE mode (8 GB / 4 vCPU; no production cluster, no observability)
	SECMLOPS_LITE=1 vagrant up
hosts:      ## print the /etc/hosts line and where to put it on this OS
	@echo "192.168.56.20 harbor.secmlops.com mlflow.secmlops.com s3.secmlops.com bao.secmlops.com secobserve.secmlops.com grafana.secmlops.com staging.secmlops.com apps.secmlops.com course.secmlops.com course-staging.secmlops.com"
	@echo "Linux/macOS: sudo nano /etc/hosts   |   Windows 11: notepad (as Administrator) C:\\Windows\\System32\\drivers\\etc\\hosts"

# ---------- optional Windows 11 machine ----------
win-box:        ## build the Windows 11 Vagrant box from YOUR licensed ISO (packer/windows11)
	packer/windows11/build.sh
up-win:         ## start the Windows 11 VM (needs the box from win-box)
	SECMLOPS_WIN11=1 vagrant up win11
provision-win:  ## configure the Windows 11 VM with Ansible, run FROM the Ubuntu VM over WinRM
	vagrant ssh lab -c "cd /vagrant/ansible && ansible-galaxy collection install -r requirements.yml -p ~/.ansible/collections >/dev/null && ansible-playbook -i windows.ini windows.yml -e win_ip=$${WIN_IP:-192.168.56.21}"
win-agent:      ## register the Windows Azure DevOps agent: make win-agent AZDO_URL=... AZDO_PAT=...
	SECMLOPS_WIN11=1 vagrant winrm win11 -c "C:\\agents\\register-azdo.ps1 -Url '$(AZDO_URL)' -Pat '$(AZDO_PAT)'"
win-runner-github: ## register the Windows GitHub runner: make win-runner-github GH_REPO_URL=... GH_RUNNER_TOKEN=...
	SECMLOPS_WIN11=1 vagrant winrm win11 -c "C:\\agents\\register-github.ps1 -RepoUrl '$(GH_REPO_URL)' -Token '$(GH_RUNNER_TOKEN)'"
down-win:
	SECMLOPS_WIN11=1 vagrant halt win11

# ---------- cloud replicas (CLOUD=aws | gcp | azure) ----------
CLOUD ?= azure
cloud-init:     ## one-time: download the provider for the chosen cloud
	cd tofu/$(CLOUD) && tofu init
cloud-plan:     ## show what would be created in the chosen cloud
	cd tofu/$(CLOUD) && tofu plan
cloud-apply:    ## create the cloud lab (VM + network + DNS) and provision it with the same Ansible
	cd tofu/$(CLOUD) && tofu apply
cloud-ssh:      ## open a shell on the cloud lab
	cd tofu/$(CLOUD) && $$(tofu output -raw ssh)
cloud-log:      ## follow provisioning on the cloud lab
	cd tofu/$(CLOUD) && $$(tofu output -raw ssh) -t 'tail -f /var/log/secmlops-provision.log'
cloud-replica:  ## prove the cloud lab equals the local lab (tools, smoke, commit)
	scripts/replica-check.sh $$(cd tofu/$(CLOUD) && tofu output -raw ssh | sed 's/^ssh -i [^ ]* //')
cloud-destroy:  ## delete the cloud lab
	cd tofu/$(CLOUD) && tofu destroy
