#!/usr/bin/env bash
set -euo pipefail

k3s_state=$(systemctl is-active k3s 2>/dev/null || echo "not-found")

if [[ "$k3s_state" == "active" ]]; then
  version=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null || echo "unknown")
  echo "k3s   active   $version"
else
  echo "k3s   $k3s_state"
fi
