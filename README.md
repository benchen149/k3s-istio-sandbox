# k3s-istio-sandbox

k3s cluster with Istio service mesh for Claude Code web sandbox.

## Prerequisites

- Linux host (Ubuntu 22.04+ recommended)
- `curl`, `envsubst` installed
- sudo access (for k3s installation)

## Quick Start

```bash
# Full setup: k3s + Istio (default versions)
make install

# Specify Istio version — k3s version auto-matched
make install ISTIO_VERSION=1.29.2

# Override both versions explicitly
make install ISTIO_VERSION=1.29.2 K3S_VERSION=v1.33.1+k3s1

# Verify
make verify

# Tear down (Istio + k3s)
make uninstall

# Tear down individually
make uninstall-istio   # remove Istio only
make uninstall-k3s     # remove k3s only
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
│   └── config.env              # versions, paths, compatibility table
├── scripts/
│   ├── install-k3s.sh          # Install k3s (traefik disabled)
│   ├── install-istio.sh        # Download istioctl + install Istio
│   ├── verify.sh               # Verify cluster + Istio health
│   ├── uninstall-istio.sh      # Remove Istio only
│   ├── uninstall-k3s.sh        # Remove k3s only
│   └── uninstall.sh            # Remove both
├── samples/
│   ├── 01-deploy/              # Deployment + Service (nginx)
│   ├── 02-ingress/             # Gateway + VirtualService
│   ├── 03-traffic/             # DestinationRule + weighted VirtualService
│   ├── 04-security/            # AuthorizationPolicy (allow / deny)
│   └── 05-telemetry/           # Telemetry (tag overrides, metric disable)
└── tools/
    └── istio/
        └── profiles/
            └── default.yaml    # IstioOperator config (single-node)
```

## Notes

- Traefik is disabled on k3s install (avoids port conflicts with Istio ingress gateway)
- Istio is installed with Canary revision support (`revision` field set)
- Single-node setup; HPA min/max replicas set to 1
