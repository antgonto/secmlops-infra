#!/usr/bin/env bash
# Post-provision health checks. Run inside the VM (make smoke).
set -uo pipefail
pass=0; fail=0
check () {  # $1=label  $2=command
  if eval "$2" >/dev/null 2>&1; then echo "ok:   $1"; pass=$((pass+1))
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}

check "docker running"        "docker info"
check "core compose up"       "docker compose -f /opt/secmlops/core/compose.yml ps -q | grep ."
check "S3 gateway reachable"  "curl -s -o /dev/null -w %{http_code} http://localhost:7070/ | grep -Eq '200|403'"
check "MLflow reachable"      "curl -sf http://localhost:5000/health"
check "OpenBao reachable"     "curl -sf http://localhost:8200/v1/sys/health"
check "SecObserve reachable"  "curl -sf http://localhost:8081/api/health/ || curl -sf http://localhost:8081/"
LITE=$(grep -q "lite: true" /opt/secmlops/lite.flag 2>/dev/null && echo 1 || echo 0)
[ "$LITE" = 1 ] || check "Grafana reachable"     "curl -sf http://localhost:3000/api/health"
[ "$LITE" = 1 ] || check "Prometheus reachable"  "curl -sf http://localhost:9090/-/healthy"
check "Harbor reachable"      "curl -sf http://localhost:8080/api/v2.0/health"
check "k3s staging ready"     "k3s kubectl get nodes | grep -w staging"
[ "$LITE" = 1 ] || check "k3s production ready"  "KUBECONFIG=/etc/rancher/k3s/prod.yaml k3s kubectl get nodes | grep -w production"
check "apps namespace"        "k3s kubectl get ns apps"
check "infra namespace"       "k3s kubectl get ns infra"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
