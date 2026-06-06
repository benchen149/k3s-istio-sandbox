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
- 與 kind 並存 / 拆除時的注意事項見 [docs/k3s-kind-coexistence.md](docs/k3s-kind-coexistence.md)

## 研究與驗證流程（Research & Verification Workflow）

調查「某個 Istio 版本的某功能 / feature flag 是否存在、行為是否如預期」時，採**兩階段**分工 —— 雲端查 source、地端做實證。兩者各有不可取代的能力，缺一不可。

| 階段 | 在哪做 | 能回答的問題 | 為什麼在這 |
|------|--------|--------------|-----------|
| **① Source 查證** | Claude Code 雲端 sandbox（或地端） | 「該功能 / flag 在這版**是否存在**」 | 有網路，可查 upstream Istio 任意 tag 原始碼、做跨版本比對；無需叢集 |
| **② 執行期驗證** | **地端 k3s + 對應版 Istio** | 「打開後**行為是否真的如描述**」 | 需要真實 istiod / gateway，雲端無 sudo/systemd 跑不了 k3s |

### 注意事項

- **Feature flag 是編進 istiod 的 Go source**，不在 release tarball 的 CRD/helm chart 裡 → 查存在性要看該版 tag 的 `pilot/pkg/features/` **整個目錄**（套件曾重構拆檔，只 grep `pilot.go` 會誤判）。
- 雲端 GitHub 整合是 OAuth app，**無 Issues 寫權限** → 研究結論在雲端產出，但**開 issue / 回填結論要用地端 `gh`**。
- 執行期實驗會動到 running istiod，**測完務必還原**（移除 env、rollback、確認叢集回復原狀）。

### 範例：`PILOT_FILTER_GATEWAY_CLUSTER_CONFIG` @ Istio 1.29.2

完整紀錄見 [issue #15](https://github.com/benchen149/k3s-istio-sandbox/issues/15)：

1. **① Source 查證**：查 tag `1.29.2` 的 `pilot/pkg/features/experimental.go`，確認 flag 仍存在（預設 `false`），並追出它在 1.22 起從 `pilot.go` 搬到 `experimental.go`。
2. **② 執行期驗證**：在地端 Istio 1.29.2 上 `kubectl set env` 開啟 flag、rollout istiod，用 `istioctl proxy-config clusters <ingressgateway>` 對照 —— gateway 收到的 cluster 由 **21 降到 6**（outbound service cluster 16 → 1，只留下被 VirtualService 引用的 `nginx.default`），行為與 source 描述一致；測畢還原。

## Slack Integration

`/claude <message>` slash command 可從 Slack 觸發 Claude，自動執行 k3s-istio-sandbox 操作並回傳結果。

### 架構

```
Slack /claude <message>
    → POST /slack/command（VM 上的 webhook server）
    → 立即回 ⏳ 處理中...
    → 背景呼叫 Claude API（bash tool）
    → Claude 執行 make / kubectl / gh 指令
    → 結果 POST 回 Slack thread
```

### 安裝步驟

1. 安裝相依套件：

```bash
pip3 install -r requirements.txt
```

> **雲端 sandbox**：Claude Code 雲端環境的 Setup script 執行時，working directory 不一定位於 repo 根目錄，讀不到 `requirements.txt`，因此 Setup script 內須直接列出相依套件（pin 請與本 repo `requirements.txt` 保持一致）。`make test` 透過 `python3 -m pytest` 執行，確保測試跑在安裝依賴的同一個 Python 環境，本機 / 雲端 / CI 行為一致。

2. 複製環境變數範本並填入真實值：

```bash
cp .env.example .env
# 編輯 .env，填入 SLACK_SIGNING_SECRET / SLACK_BOT_TOKEN / ANTHROPIC_API_KEY
```

3. 啟動 webhook server：

```bash
make serve
```

4. 停止 webhook server：

```bash
make serve-stop
```

### Slack App 設定（一次性）

1. 至 https://api.slack.com/apps → "From scratch" 建立 App
2. **Slash Commands** → 新增 `/claude` → Request URL：`http://<VM_IP>:5000/slack/command`
3. **OAuth & Permissions** → Bot Token Scopes：`commands`、`chat:write`
4. 安裝 App 至 workspace → 複製 Bot Token → 存至 `.env`
5. **Basic Information** → Signing Secret → 存至 `.env`

### 使用範例

```
/claude 請幫我安裝 Istio 1.25.0 並驗證 sidecar injection
/claude make status
/claude 列出目前 k3s 的所有 pod
```
