# k3s-istio-sandbox

k3s cluster with Istio service mesh for Claude Code web sandbox.

## Prerequisites

- Linux host (Ubuntu 22.04+ recommended)
- `curl`, `envsubst` installed
- sudo access (for k3s installation)

## Quick Start

```bash
# Full setup: k3s + Istio
make install

# Verify
make verify

# Tear down
make uninstall
```

## Configuration

Edit `config/config.env` to change versions:

| Variable | Default | Description |
|----------|---------|-------------|
| `istio_version` | `1.24.0` | Istio version to install |
| `istio_label` | `1-24-0` | Revision label (hyphens) |
| `KUBECONFIG` | `/etc/rancher/k3s/k3s.yaml` | k3s kubeconfig path |

## Structure

```
├── config/
│   └── config.env          # versions and paths
├── scripts/
│   ├── install-k3s.sh      # Install k3s (traefik disabled)
│   ├── install-istio.sh    # Download istioctl + install Istio
│   ├── verify.sh           # Verify cluster + Istio health
│   └── uninstall.sh        # Remove Istio and k3s
└── tools/
    └── istio/
        └── profiles/
            └── default.yaml  # IstioOperator config (single-node)
```

## Notes

- Traefik is disabled on k3s install (avoids port conflicts with Istio ingress gateway)
- Istio is installed with Canary revision support (`revision` field set)
- Single-node setup; HPA min/max replicas set to 1
