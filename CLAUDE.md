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
