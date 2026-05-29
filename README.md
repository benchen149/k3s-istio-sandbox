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

# Verify cluster + Istio health
make verify

# Smoke test: deploy nginx, test HTTP routing via IngressGateway, cleanup
make verify-samples

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

## Testing the Ingress

After `make install` (or `make verify-samples`), nginx is reachable via the Istio IngressGateway.
Get the node IP:

```bash
kubectl get nodes -o wide   # INTERNAL-IP column
```

**Option 1 — curl with Host header (no DNS change needed)**

```bash
curl -H "Host: nginx.local" http://<NODE_IP>/
```

**Option 2 — add to /etc/hosts (enables browser access)**

```bash
echo "<NODE_IP>  nginx.local" | sudo tee -a /etc/hosts
curl http://nginx.local/
# or open http://nginx.local/ in a browser
```

To remove the hosts entry when done:

```bash
sudo sed -i '/nginx\.local/d' /etc/hosts
```

## Smoke Test Scope

`make verify-samples` only runs **01-deploy + 02-ingress**. The reasoning:

| Sample | Why included / excluded |
|--------|------------------------|
| 01-deploy | Verifies k3s scheduling and Istio sidecar injection |
| 02-ingress | Verifies IngressGateway routing (the critical end-to-end path) |
| 03-traffic | Requires deploying two app versions and observing traffic distribution — better explored manually |
| 04-security | Requires creating multiple namespaces and verifying connection rejection — not suitable for automated teardown |
| 05-telemetry | Configuration-only change with no immediately observable output — requires a metrics backend to verify |

The two included samples together confirm the most important installation invariant: a workload can be injected with a sidecar and reached through the ingress gateway.

## Notes

- Traefik is disabled on k3s install (avoids port conflicts with Istio ingress gateway)
- Istio is installed with Canary revision support (`revision` field set)
- Single-node setup; HPA min/max replicas set to 1
