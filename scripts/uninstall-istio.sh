#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"

export KUBECONFIG

echo "==> Removing Istio..."
export PATH="$FOLDER_PATH_istio/bin:$PATH"
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found

echo "==> Cleaning up download cache..."
rm -rf "$FOLDER_PATH_download"

echo "==> Istio removed."
