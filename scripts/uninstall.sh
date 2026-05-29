#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"

echo "==> Removing Istio..."
export PATH="$FOLDER_PATH_istio/bin:$PATH"
export KUBECONFIG
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found

echo "==> Uninstalling k3s..."
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || echo "(k3s not installed)"

echo "==> Cleaning up download cache..."
rm -rf "$FOLDER_PATH_download"

echo "==> Done."
