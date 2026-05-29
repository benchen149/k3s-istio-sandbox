#!/usr/bin/env bash
set -euo pipefail

abspath=$(cd "$(dirname "$0")/.." && pwd)
source "$abspath/config/config.env"
export KUBECONFIG

NS=default

cleanup() {
  echo ""
  echo "==> Cleaning up sample resources..."
  kubectl delete -f "$abspath/samples/02-ingress/gateway-virtualservice.yaml" --ignore-not-found 2>/dev/null
  kubectl delete -f "$abspath/samples/01-deploy/nginx.yaml" --ignore-not-found 2>/dev/null
  kubectl label namespace "$NS" istio-injection- --overwrite 2>/dev/null || true
}
trap cleanup EXIT

# ── 1. Enable sidecar injection ───────────────────────────────────────────────
echo "==> [1/4] Enable sidecar injection on namespace '$NS'..."
kubectl label namespace "$NS" istio-injection=enabled --overwrite

# ── 2. Deploy samples ─────────────────────────────────────────────────────────
echo "==> [2/4] Deploy nginx + Gateway / VirtualService..."
kubectl apply -f "$abspath/samples/01-deploy/nginx.yaml"
kubectl apply -f "$abspath/samples/02-ingress/gateway-virtualservice.yaml"

# ── 3. Wait for pod Ready ─────────────────────────────────────────────────────
echo "==> [3/4] Waiting for nginx pod to be Ready..."
kubectl -n "$NS" wait --for=condition=Ready pod -l app=nginx --timeout=90s

# ── 4. Resolve IngressGateway address ─────────────────────────────────────────
echo "==> [4/4] Testing HTTP routing via IngressGateway..."

# Wait for klipper-lb to assign external IP (k3s single-node)
for i in $(seq 1 20); do
  INGRESS_IP=$(kubectl -n istio-system get svc istio-ingressgateway \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [[ -n "$INGRESS_IP" ]] && break
  sleep 3
done

if [[ -z "$INGRESS_IP" ]]; then
  # Fallback: node internal IP + NodePort
  INGRESS_IP=$(kubectl get nodes \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  INGRESS_PORT=$(kubectl -n istio-system get svc istio-ingressgateway \
    -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
else
  INGRESS_PORT=80
fi

URL="http://${INGRESS_IP}:${INGRESS_PORT}/"
echo "    GET $URL  (Host: nginx.local)"

# Retry up to 10 times — Istio config propagation to EnvoyProxy takes a few seconds
HTTP_CODE="000"
for i in $(seq 1 10); do
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -H "Host: nginx.local" "$URL")
  [[ "$HTTP_CODE" == "200" ]] && break
  echo "    attempt $i: HTTP $HTTP_CODE, retrying in 5s..."
  sleep 5
done

if [[ "$HTTP_CODE" == "200" ]]; then
  echo ""
  echo "==> verify-samples PASSED (HTTP $HTTP_CODE) ✓"
else
  echo ""
  echo "==> verify-samples FAILED (HTTP $HTTP_CODE)"
  exit 1
fi
