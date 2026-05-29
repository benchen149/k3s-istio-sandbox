#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"

export KUBECONFIG

echo "=== k3s Node ==="
kubectl get nodes -o wide

echo ""
echo "=== Istio System Pods ==="
kubectl -n istio-system get pods

echo ""
echo "=== Istio Version ==="
export PATH="$FOLDER_PATH_istio/bin:$PATH"
istioctl version 2>/dev/null || echo "(istioctl not found in $FOLDER_PATH_istio/bin)"
