# Claude Code — Project Conventions

## 專案簡介

`k3s-istio-sandbox`：使用 k3s 建立輕量 Kubernetes 單節點環境，整合 Istio service mesh，供 Claude Code web sandbox 使用。

---

## 開發流程

所有功能開發皆走 **GitHub Flow**：

```
issue → feature branch → commit → PR → merge to develop → sync PR → merge to main
```

使用 `/github-flow` slash command 自動引導整個流程。

### Branch 策略

| Branch | 用途 |
|--------|------|
| `main` | 穩定版本，只接受來自 `develop` 的 PR merge |
| `develop` | 主要開發 branch，feature branch 從此切出、PR 也 merge 回此 |
| `{issue-number}-{slug}` | Feature branch，merge 後自動刪除 |

**絕對不可刪除 `main` 與 `develop`。**

---

## 環境設定

新環境第一次執行 `/setup-github-ssh` 完成設定：
- SSH key 產生（必須設定 passphrase）
- GitHub known_hosts fingerprint 驗證
- `gh` CLI 登入（Fine-grained Token，限定單一 repo）
- git config user.email / user.name

### GitHub Token（gh CLI）

- 使用 Fine-grained Personal Access Token，限定此 repo
- 最小權限：Contents / Issues / Pull requests Read & Write、Metadata Read-only
- 有效期：建議 90 天
- 儲存位置：`~/.config/gh/hosts.yml`（明文，不可納入 git）

---

## 版本資訊

| Component | Version |
|-----------|---------|
| k3s | latest stable |
| Istio | 1.24.0 |

版本設定檔：`config/config.env`

---

## 常用 Make 指令

| 指令 | 說明 |
|------|------|
| `make install` | 安裝 k3s + Istio |
| `make install-k3s` | 僅安裝 k3s |
| `make install-istio` | 僅安裝 Istio（需 k3s 已啟動） |
| `make verify` | 驗證叢集與 Istio 健康狀態 |
| `make uninstall` | 移除 Istio 與 k3s |

---

## Claude Slash Commands

| Command | 說明 |
|---------|------|
| `/setup-github-ssh` | 新環境一次性設定：SSH key、GitHub known_hosts、gh CLI 登入 |
| `/github-flow` | 完整開發流程（Mode 1：issue → PR → merge；Mode 2：關閉 PR / Issue） |

---

## 雲端 vs 本機分工

本 repo 有三層，Claude Code 雲端 sandbox 只在前兩層可用：

| 層 | 內容 | 雲端 | 本機 |
|----|------|------|------|
| 程式 / 工具 | `slack_webhook.py`、tests、Makefile、docs、scripts | ✅ 改 code、跑 `make test` | ✅ |
| 研究查證 | 查 upstream Istio 原始碼、版本比對、feature flag 存在性 | ✅ 有網路、查 tag source | ✅ |
| 執行期 / 叢集 | k3s + Istio 安裝、`verify-samples`、flag 執行期行為 | ❌ 無 sudo / systemd，k3s 裝不起來 | ✅ |

### 任務路由準則（這件事該在哪做）

- **叢集相關**（`make install`、`install-k3s`、`verify-samples`、flag 執行期行為）→ **一律本機**。雲端跑不了 k3s。
- **開 issue** → **一律本機 gh**。雲端 GitHub 整合是 OAuth app，無 Issues 寫權限（實測 token 權限不足）。
- **push branch / 開 PR** → **未驗證雲端是否可行，未確認前一律本機**。要放寬請先在雲端 session 實測 push + PR 成功再改此處。
- **改 code / 跑測試 / source 研究** → 雲端或本機皆可。雲端優勢：乾淨可重現環境（issue #8 即由此暴露）、不佔本機、可平行、隨處可用。

### 雲端注意事項

- Setup script 執行時 working directory 不在 repo 根，`pip install -r requirements.txt` 會失敗 → 須**內聯列出依賴**（pin 與 `requirements.txt` 一致）。
- 雲端**沒有 `gh` CLI**，GitHub 操作走 MCP；別在雲端叫它跑 `gh ...`。

---

## Issue / PR 標題準則

- **一律使用英文**
- 格式：`<type>: <short description>`
- 範例：`feat: add xxx`、`fix: xxx not working`、`chore: update xxx`

---

## 安全規範

- SSH key passphrase 必須設定，不可留空
- known_hosts 加入前必須對比 GitHub 官方 fingerprint
- `gh` CLI token 不可提交至任何 repo 或 dotfiles
- `~/.ssh/id_ed25519` 不可複製到他處或提交至任何 repo
- Feature branch merge 後自動刪除，`main`、`develop` 永遠保留

---

## 行為準則（Claude 自動遵循）

### Systematic Debugging

**鐵則：沒有 root cause 就不動手修。** 任何 fix 必須先完成以下四階段：

1. **Root Cause Investigation** — 重現問題、蒐集 log/evidence、定位是哪一層出錯
2. **Pattern Analysis** — 對比正常與異常狀態的具體差異
3. **Hypothesis Testing** — 一次只測一個假設，用最小改動驗證
4. **Implementation** — 先寫 reproducing test，再套用 focused fix，最後確認修復

### Verification Before Completion

**鐵則：先有 evidence 再說完成。** 在任何聲稱「修好了」、「測試通過」之前，必須：

1. 找出能**證明**你主張的指令
2. **當場執行**，取得新的輸出
3. 閱讀完整輸出與 exit code
4. 確認結果真的支持你的主張
5. 附上 evidence 才能陳述結論

### Test-Driven Development

**鐵則：沒有失敗的測試就不寫 production code。** 嚴格遵循 Red → Green → Refactor：

- **Red**：先寫一個**會失敗**的測試，確認它真的失敗了
- **Green**：寫最少量的 code 讓測試通過
- **Refactor**：維持測試通過的前提下整理程式碼
