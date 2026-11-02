#!/usr/bin/env bash
# Verify every tool the course uses is present and print its version.
# Usage: tools-check [--laptop|--runner]   (default: --runner = everything)
set -uo pipefail
MODE="${1:---runner}"
ok=0; miss=0
chk () {  # name  version-command  [scope]
  local scope="${3:-both}"
  [[ "$MODE" == "--laptop" && "$scope" == "runner" ]] && return
  if command -v "$1" >/dev/null 2>&1; then
    v=$(bash -c "$2" 2>/dev/null | head -1 | cut -c1-60); printf '  ok   %-14s %s\n' "$1" "${v:-present}"; ok=$((ok+1))
  else printf '  MISS %-14s\n' "$1"; miss=$((miss+1)); fi
}
echo "== core =="
chk git        "git --version"
chk python3    "python3 --version"
chk docker     "docker --version"
chk jq         "jq --version"
chk yq         "yq --version"
chk curl       "curl --version"
echo "== infrastructure (laptop) =="
chk vagrant    "vagrant --version"                laptop
chk VBoxManage "VBoxManage --version"             laptop
chk tofu       "tofu version"
echo "== kubernetes =="
chk kubectl    "kubectl version --client -o yaml | grep gitVersion"
chk helm       "helm version --short"
chk kyverno    "kyverno version"
echo "== supply chain =="
chk cosign     "cosign version 2>&1 | grep GitVersion"
chk trivy      "trivy --version"
chk syft       "syft version | grep Version"
chk grype      "grype version | grep Version"
chk hadolint   "hadolint --version"
echo "== code gates =="
chk opengrep   "opengrep --version"
chk gitleaks   "gitleaks version"
chk actionlint "actionlint -version"
chk zizmor     "zizmor --version"
chk ruff       "ruff --version"
chk mypy       "mypy --version"
chk pytest     "pytest --version"
echo "== ML security =="
chk modelscan  "modelscan --version"
chk picklescan "picklescan --version 2>&1 | head -1"
chk dvc        "dvc --version"
chk mlflow     "mlflow --version"
chk cyclonedx-py "cyclonedx-py --version"
python3 -c "import art, giskard, pandera, safetensors" 2>/dev/null && echo "  ok   python libs   art, giskard, pandera, safetensors" || { echo "  MISS python libs   (art/giskard/pandera/safetensors)"; miss=$((miss+1)); }
python3 -c "import garak" 2>/dev/null && echo "  ok   garak          (optional)" || echo "  --   garak          optional, LLM labs only"
echo "== offensive =="
chk nmap       "nmap --version | head -1"
chk nuclei     "nuclei -version 2>&1 | grep -i version"
chk katana     "katana -version 2>&1 | grep -i version"
chk testssl.sh "testssl.sh --version 2>&1 | grep -i testssl"
docker image inspect ghcr.io/rapidast/rapidast:latest >/dev/null 2>&1 && echo "  ok   rapidast       (docker image)" || echo "  MISS rapidast       docker pull ghcr.io/rapidast/rapidast:latest"
echo "== identity / secrets / platforms =="
chk bao        "bao version"
chk az         "az version -o tsv 2>/dev/null | head -1"
chk gh         "gh --version | head -1"                 laptop
chk glab       "glab --version"                         laptop
chk aws        "aws --version"
echo "== runners (runner host only) =="
[[ "$MODE" == "--runner" ]] && { chk gitlab-runner "gitlab-runner --version | grep Version" runner; [ -x /opt/gh-runner/config.sh ] && echo "  ok   gh-runner      /opt/gh-runner" || echo "  MISS gh-runner"; [ -x /opt/azagent/config.sh ] && echo "  ok   azdo-agent     /opt/azagent" || echo "  MISS azdo-agent"; }
echo "---"; echo "present=$ok missing=$miss"; [ "$miss" -eq 0 ]
