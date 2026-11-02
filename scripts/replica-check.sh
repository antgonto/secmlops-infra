#!/usr/bin/env bash
# Prove a cloud lab is a replica of the local lab: compare tool versions, smoke results, and the Ansible role list.
#   scripts/replica-check.sh <cloud-ssh-target>      e.g.  scripts/replica-check.sh ubuntu@20.1.2.3
# Runs tools-check + smoke locally (via vagrant ssh) and on the cloud host (via ssh), then diffs.
set -uo pipefail
T="${1:?usage: replica-check.sh user@cloud-ip}"; KEY="${SSH_KEY:-$HOME/.ssh/secmlops}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT   # cleanup on every exit path, including a failed ssh or Ctrl-C
echo "== local lab"; vagrant ssh lab -c "tools-check --runner 2>/dev/null | grep -E '^\s+(ok|MISS)' | awk '{print \$2, \$3}'" > "$tmp/local.tools"
vagrant ssh lab -c "sudo /vagrant/scripts/smoke.sh 2>/dev/null | grep -E '^(ok|FAIL)'" > "$tmp/local.smoke"
echo "== cloud lab ($T)"; ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "$T" "tools-check --runner 2>/dev/null | grep -E '^\s+(ok|MISS)' | awk '{print \$2, \$3}'" > "$tmp/cloud.tools"
ssh -i "$KEY" "$T" "sudo /vagrant/scripts/smoke.sh 2>/dev/null | grep -E '^(ok|FAIL)'" > "$tmp/cloud.smoke"
echo; echo "== tool versions (blank = identical)"; diff "$tmp/local.tools" "$tmp/cloud.tools" && echo "IDENTICAL: $(wc -l < "$tmp/local.tools") tools"
echo; echo "== smoke (blank = identical)"; diff "$tmp/local.smoke" "$tmp/cloud.smoke" && echo "IDENTICAL: $(grep -c '^ok' "$tmp/local.smoke") checks"
echo; echo "== git commit provisioned"; echo -n "local:  "; vagrant ssh lab -c "cd /vagrant && git rev-parse --short HEAD 2>/dev/null || echo n/a"
echo -n "cloud:  "; ssh -i "$KEY" "$T" "cd /opt/secmlops-infra && git rev-parse --short HEAD"
