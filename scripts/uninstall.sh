#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)

bash "$abspath/scripts/uninstall-istio.sh"
bash "$abspath/scripts/uninstall-k3s.sh"

echo "==> Done."
