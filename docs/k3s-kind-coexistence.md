# k3s 與 kind 並存注意事項

本 repo 用 k3s 做**單版本深入**的 Istio sandbox；kind 則常用於**多叢集 / 多版本矩陣**。
兩者在同一台本機並存是常見情境，本文說明並存與拆除時要注意的耦合點。

> 以下基於 k3s 官方 installer / `k3s-uninstall.sh` 與 kind 的已知行為。實機行為請以
> `/usr/local/bin/k3s-uninstall.sh` 的實際內容為準。

---

## 核心衝突：共用的 `kubectl`

這是並存時**唯一實際會踩到**的點：

- k3s 官方 installer（`curl get.k3s.io | sh`，見 `scripts/install-k3s.sh`）會在
  `/usr/local/bin` 建立 `kubectl`、`crictl`、`ctr` 等 symlink，指向 `/usr/local/bin/k3s`。
- **kind 不自帶 `kubectl`**。kind 只負責用 Docker 起叢集，操作叢集仍需獨立的 `kubectl`。
- 因此執行 `make uninstall-k3s`（→ `k3s-uninstall.sh`）時，`/usr/local/bin/kubectl`
  這個 symlink 會被一併移除，kind 叢集就「突然沒有 kubectl 可用」。

這不算 k3s 與 kind 互相破壞，而是 **k3s 把它帶來的共用 `kubectl` 一起帶走了**。

### ⚠️ 額外風險

若你曾手動把一份**獨立的** `kubectl` binary 放到 `/usr/local/bin/kubectl`，
`k3s-uninstall.sh` 同樣會把它刪掉。

---

## 建議：獨立安裝一份 `kubectl`

要徹底解除這個耦合，**不要依賴 k3s 帶的 symlink**，自行裝一份放在 k3s 不會碰的位置：

- 放 `~/.local/bin/kubectl` 或 `/usr/bin/kubectl`，**避開** `/usr/local/bin/kubectl`。
- 確保 PATH 中該位置的優先序符合預期。

這樣：

| 狀態 | 結果 |
|------|------|
| k3s 已裝 | `/usr/local/bin/kubectl` 存在；PATH 順序決定用哪一份 |
| `make uninstall-k3s` 後 | 只刪掉 `/usr/local/bin/kubectl`，你獨立那份還在，kind 照常操作 |

---

## 執行期：兩者其實是隔離的

拆掉 k3s **不會**弄壞 kind 叢集，因為兩者執行期各走各的：

| 項目 | k3s | kind | 拆 k3s 後 |
|------|-----|------|-----------|
| 執行期 | systemd + 內建 containerd | Docker container | k3s 進程 / service 被清掉；kind 在 Docker 裡，獨立存活 |
| 網路 | flannel + 改 iptables | Docker bridge | `k3s-uninstall.sh` 設計上會清 flannel / iptables / mount |
| kubeconfig | `/etc/rancher/k3s/k3s.yaml` | `~/.kube/config` | k3s 的檔被清除；**不會動** kind 寫入的 `~/.kube/config` |

---

## `KUBECONFIG` 環境變數

`config/config.env` 把 `KUBECONFIG` 指向 k3s 的 `k3s.yaml`（`install-k3s.sh`、
`uninstall-istio.sh` 都會 `source` 它）。

若你的 shell 仍 export 著這個值，拆掉 k3s 後該檔不存在，`kubectl` 會抱怨找不到 config。
切回 kind 時記得：

```bash
# 切到 kind 的 context（kind 寫在 ~/.kube/config）
kubectl config use-context kind-<cluster-name>

# 或直接 unset 掉釘在 k3s 的 KUBECONFIG
unset KUBECONFIG
```

---

## 速查

| 我想做的事 | 注意 |
|------------|------|
| k3s 與 kind 同時裝著 | 確認你用的是「獨立 kubectl」，而非 k3s 的 symlink |
| `make uninstall-k3s` | 會移除 `/usr/local/bin/kubectl`；獨立那份 kubectl 不受影響 |
| 拆 k3s 後改用 kind | `kubectl config use-context kind-...`，必要時 `unset KUBECONFIG` |
| 擔心 kind 叢集被弄壞 | 不會；kind 在 Docker，與 k3s 執行期隔離 |
