#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"

echo "==> Installing k3s ${K3S_VERSION} (traefik disabled, kubeconfig world-readable)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
  --disable traefik \
  --write-kubeconfig-mode 644

echo "==> Waiting for k3s node to be Ready..."
until kubectl --kubeconfig="$KUBECONFIG" get nodes | grep -q "Ready"; do
  sleep 3
done
kubectl --kubeconfig="$KUBECONFIG" get nodes

echo "==> k3s installed successfully."
