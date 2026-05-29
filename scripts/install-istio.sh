#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"

export KUBECONFIG

# ── 1. Download istioctl ──────────────────────────────────────────────────
mkdir -p "$FOLDER_PATH_download"
if [[ ! -f "$FOLDER_PATH_istio/bin/istioctl" ]]; then
  echo "==> Downloading Istio $istio_version..."
  (cd "$FOLDER_PATH_download" && \
    curl -sL https://istio.io/downloadIstio | \
    ISTIO_VERSION="$istio_version" TARGET_ARCH=x86_64 sh -)
fi
export PATH="$FOLDER_PATH_istio/bin:$PATH"
echo "==> istioctl version: $(istioctl version --remote=false)"

# ── 2. Install Istio ──────────────────────────────────────────────────────
echo "==> Installing Istio $istio_version (revision: $istio_label)..."
envsubst '$istio_label' < "$abspath/tools/istio/profiles/default.yaml" \
  | istioctl install -y -f -

# ── 3. Verify ─────────────────────────────────────────────────────────────
echo "==> Waiting for Istio pods to be Ready..."
kubectl -n istio-system wait --for=condition=Ready pod --all --timeout=120s
kubectl -n istio-system get pods

echo "==> Istio $istio_version installed successfully."
