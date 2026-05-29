#!/usr/bin/env bash
set -euo pipefail

echo "==> Uninstalling k3s..."
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || echo "(k3s not installed)"

echo "==> k3s removed."
