# Slack Claude Trigger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `/claude <message>` Slack slash command，觸發 VM 上的 Claude API（含 bash tool），執行 k3s-istio-sandbox 操作，並將結果回傳 Slack thread。

**Architecture:** Flask webhook server 接收 Slack slash command → 驗證 HMAC 簽章 → 立即回 HTTP 200 → 背景執行 Claude agentic loop（bash tool 執行 make/kubectl 指令）→ 將結果 POST 回 Slack `response_url`。

**Tech Stack:** Python 3, Flask 3, anthropic SDK, python-dotenv, requests, pytest

---

## File Structure

| 路徑 | 類型 | 用途 |
|------|------|------|
| `scripts/slack_webhook.py` | 新建 | Flask webhook server（主程式） |
| `scripts/slack_webhook_system_prompt.txt` | 新建 | Claude system prompt（定義可執行操作範圍） |
| `.env.example` | 新建 | 環境變數範本（無真實值） |
| `requirements.txt` | 新建 | Python 相依套件 |
| `conftest.py` | 新建 | pytest 根設定（加 scripts/ 到 sys.path） |
| `tests/__init__.py` | 新建 | 讓 tests/ 成為 Python package |
| `tests/test_slack_webhook.py` | 新建 | 單元測試 |
| `Makefile` | 修改 | 加入 serve、serve-stop、test targets |
| `.gitignore` | 修改 | 加入 `.env` |
| `README.md` | 修改 | 加入 Slack Integration 段落 |

---

### Task 1: 建立 Python 環境基礎設施

**Files:**
- Create: `requirements.txt`
- Create: `.env.example`
- Create: `conftest.py`
- Create: `tests/__init__.py`
- Modify: `.gitignore`

- [ ] **Step 1: 建立 requirements.txt**

```
flask>=3.0
anthropic>=0.40
python-dotenv>=1.0
requests>=2.32
pytest>=8.0
```

- [ ] **Step 2: 建立 .env.example**

```bash
# Slack App Signing Secret（Basic Information → Signing Secret）
SLACK_SIGNING_SECRET=your_slack_signing_secret_here

# Slack Bot Token（OAuth & Permissions → Bot User OAuth Token）
SLACK_BOT_TOKEN=xoxb-your-token-here

# Anthropic API Key
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

- [ ] **Step 3: 加入 .env 至 .gitignore**

在 `.gitignore` 末尾加入：

```
.env
```

- [ ] **Step 4: 建立 conftest.py（root，讓 tests 能 import scripts/）**

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "scripts"))
```

- [ ] **Step 5: 建立 tests/__init__.py（空檔）**

```python
```

- [ ] **Step 6: 安裝套件**

```bash
pip3 install -r requirements.txt
```

Expected: 所有套件安裝成功，無 error。

- [ ] **Step 7: Commit**

```bash
git add requirements.txt .env.example .gitignore conftest.py tests/__init__.py
git commit -m "chore: add python deps, env template, test infra"
```

---

### Task 2: HMAC 簽章驗證（TDD）

**Files:**
- Create: `scripts/slack_webhook.py`（只含 `verify_slack_signature`）
- Create: `tests/test_slack_webhook.py`（只含 HMAC 測試）

- [ ] **Step 1: 建立最小骨架 scripts/slack_webhook.py**

```python
import hashlib
import hmac as hmac_module
import time


def verify_slack_signature(signing_secret: str, body: bytes, timestamp: str, signature: str) -> bool:
    raise NotImplementedError
```

- [ ] **Step 2: 建立 tests/test_slack_webhook.py，寫 HMAC 測試**

```python
import hashlib
import hmac as hmac_module
import time

import pytest
from slack_webhook import verify_slack_signature


def _make_sig(secret: str, body: bytes, timestamp: str) -> str:
    sig_base = f"v0:{timestamp}:{body.decode()}"
    return "v0=" + hmac_module.new(
        secret.encode(), sig_base.encode(), hashlib.sha256
    ).hexdigest()


SECRET = "test_signing_secret_abc123"


def test_verify_valid_signature():
    body = b"token=abc&text=hello"
    ts = str(int(time.time()))
    sig = _make_sig(SECRET, body, ts)
    assert verify_slack_signature(SECRET, body, ts, sig) is True


def test_verify_wrong_secret():
    body = b"token=abc&text=hello"
    ts = str(int(time.time()))
    sig = _make_sig("wrong_secret", body, ts)
    assert verify_slack_signature(SECRET, body, ts, sig) is False


def test_verify_expired_timestamp():
    body = b"token=abc"
    ts = str(int(time.time()) - 310)  # > 5 minutes ago
    sig = _make_sig(SECRET, body, ts)
    assert verify_slack_signature(SECRET, body, ts, sig) is False


def test_verify_malformed_signature():
    body = b"token=abc"
    ts = str(int(time.time()))
    assert verify_slack_signature(SECRET, body, ts, "not-a-valid-sig") is False
```

- [ ] **Step 3: 執行測試，確認 FAIL**

```bash
pytest tests/test_slack_webhook.py::test_verify_valid_signature \
       tests/test_slack_webhook.py::test_verify_wrong_secret \
       tests/test_slack_webhook.py::test_verify_expired_timestamp \
       tests/test_slack_webhook.py::test_verify_malformed_signature -v
```

Expected: 4 FAILED（NotImplementedError）

- [ ] **Step 4: 實作 verify_slack_signature**

將 `scripts/slack_webhook.py` 中的函式替換為：

```python
def verify_slack_signature(signing_secret: str, body: bytes, timestamp: str, signature: str) -> bool:
    try:
        if abs(time.time() - int(timestamp)) > 300:
            return False
        sig_base = f"v0:{timestamp}:{body.decode('utf-8')}"
        computed = "v0=" + hmac_module.new(
            signing_secret.encode(), sig_base.encode(), hashlib.sha256
        ).hexdigest()
        return hmac_module.compare_digest(computed, signature)
    except Exception:
        return False
```

- [ ] **Step 5: 執行測試，確認 PASS**

```bash
pytest tests/test_slack_webhook.py::test_verify_valid_signature \
       tests/test_slack_webhook.py::test_verify_wrong_secret \
       tests/test_slack_webhook.py::test_verify_expired_timestamp \
       tests/test_slack_webhook.py::test_verify_malformed_signature -v
```

Expected: 4 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/slack_webhook.py tests/test_slack_webhook.py
git commit -m "feat: add HMAC signature verification with tests"
```

---

### Task 3: Flask /slack/command 端點（TDD）

**Files:**
- Modify: `scripts/slack_webhook.py`（加入 Flask app + endpoint）
- Modify: `tests/test_slack_webhook.py`（加入 endpoint 測試）

- [ ] **Step 1: 在 tests/test_slack_webhook.py 末尾加入端點測試**

```python
import threading
from unittest.mock import patch
from flask import Flask


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("SLACK_SIGNING_SECRET", SECRET)
    monkeypatch.setenv("SLACK_BOT_TOKEN", "xoxb-test")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    import importlib
    import slack_webhook as sw
    importlib.reload(sw)
    app = sw.create_app()
    app.testing = True
    return app.test_client()


def test_endpoint_rejects_invalid_signature(client):
    response = client.post(
        "/slack/command",
        data={"text": "make status"},
        headers={
            "X-Slack-Request-Timestamp": str(int(time.time())),
            "X-Slack-Signature": "v0=invalid",
        },
    )
    assert response.status_code == 403


def test_endpoint_returns_200_with_pending_message(client):
    body = b"text=make+status&response_url=https%3A%2F%2Fhooks.slack.com%2Ftest"
    ts = str(int(time.time()))
    sig = _make_sig(SECRET, body, ts)

    with patch("threading.Thread.start"):
        response = client.post(
            "/slack/command",
            data=body,
            content_type="application/x-www-form-urlencoded",
            headers={
                "X-Slack-Request-Timestamp": ts,
                "X-Slack-Signature": sig,
            },
        )

    assert response.status_code == 200
    assert "處理中" in response.get_json()["text"]
```

- [ ] **Step 2: 執行新增的兩個測試，確認 FAIL**

```bash
pytest tests/test_slack_webhook.py::test_endpoint_rejects_invalid_signature \
       tests/test_slack_webhook.py::test_endpoint_returns_200_with_pending_message -v
```

Expected: 2 FAILED（AttributeError: module has no attribute 'create_app'）

- [ ] **Step 3: 在 scripts/slack_webhook.py 加入 Flask 相依 import 與 create_app**

在檔案頂端 import 區塊加入：

```python
import os
import threading

from dotenv import load_dotenv
from flask import Flask, jsonify, request
```

在檔案末尾加入：

```python
def create_app() -> Flask:
    app = Flask(__name__)
    signing_secret = os.environ["SLACK_SIGNING_SECRET"]

    @app.route("/slack/command", methods=["POST"])
    def slack_command():
        body = request.get_data()
        timestamp = request.headers.get("X-Slack-Request-Timestamp", "")
        signature = request.headers.get("X-Slack-Signature", "")

        if not verify_slack_signature(signing_secret, body, timestamp, signature):
            return jsonify({"error": "Invalid signature"}), 403

        text = request.form.get("text", "")
        response_url = request.form.get("response_url", "")

        threading.Thread(
            target=run_claude,
            args=(text, response_url, os.environ["ANTHROPIC_API_KEY"]),
            daemon=True,
        ).start()

        return jsonify({"response_type": "ephemeral", "text": "⏳ 處理中，請稍候..."})

    return app


if __name__ == "__main__":
    load_dotenv()
    create_app().run(host="0.0.0.0", port=5000)
```

在 `verify_slack_signature` 之後、`create_app` 之前加入佔位：

```python
def run_claude(user_message: str, response_url: str, anthropic_api_key: str) -> None:
    raise NotImplementedError
```

- [ ] **Step 4: 執行端點測試，確認 PASS**

```bash
pytest tests/test_slack_webhook.py::test_endpoint_rejects_invalid_signature \
       tests/test_slack_webhook.py::test_endpoint_returns_200_with_pending_message -v
```

Expected: 2 PASSED

- [ ] **Step 5: 確認先前 HMAC 測試也仍通過**

```bash
pytest tests/test_slack_webhook.py -v
```

Expected: 6 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/slack_webhook.py tests/test_slack_webhook.py
git commit -m "feat: add Flask /slack/command endpoint with signature verification"
```

---

### Task 4: Claude agentic loop（TDD）

**Files:**
- Modify: `scripts/slack_webhook.py`（實作 run_claude）
- Modify: `tests/test_slack_webhook.py`（加入 run_claude 測試）

- [ ] **Step 1: 在 tests/test_slack_webhook.py 末尾加入 run_claude 測試**

```python
from unittest.mock import MagicMock
import slack_webhook


def _make_text_block(text: str):
    block = MagicMock()
    block.type = "text"
    block.text = text
    return block


def _make_tool_use_block(tool_id: str, command: str):
    block = MagicMock()
    block.type = "tool_use"
    block.name = "bash"
    block.id = tool_id
    block.input = {"command": command}
    return block


def test_run_claude_posts_result_to_slack(monkeypatch):
    mock_response = MagicMock()
    mock_response.stop_reason = "end_turn"
    mock_response.content = [_make_text_block("✅ k3s 正常運行")]

    mock_client = MagicMock()
    mock_client.messages.create.return_value = mock_response

    posted = []
    monkeypatch.setattr(slack_webhook.anthropic, "Anthropic", lambda **kwargs: mock_client)
    monkeypatch.setattr(slack_webhook.requests, "post", lambda url, json, timeout: posted.append(json))

    slack_webhook.run_claude("make status", "https://hooks.slack.com/test", "fake-key")

    assert len(posted) == 1
    assert "✅ k3s 正常運行" in posted[0]["text"]


def test_run_claude_executes_bash_tool(monkeypatch):
    tool_response = MagicMock()
    tool_response.stop_reason = "tool_use"
    tool_response.content = [_make_tool_use_block("tool_1", "make status")]

    final_response = MagicMock()
    final_response.stop_reason = "end_turn"
    final_response.content = [_make_text_block("✅ 完成")]

    mock_client = MagicMock()
    mock_client.messages.create.side_effect = [tool_response, final_response]

    bash_calls = []
    monkeypatch.setattr(slack_webhook, "run_bash", lambda cmd: bash_calls.append(cmd) or "active")
    monkeypatch.setattr(slack_webhook.anthropic, "Anthropic", lambda **kwargs: mock_client)
    monkeypatch.setattr(slack_webhook.requests, "post", lambda url, json, timeout: None)

    slack_webhook.run_claude("make status", "https://hooks.slack.com/test", "fake-key")

    assert "make status" in bash_calls
    assert mock_client.messages.create.call_count == 2


def test_run_claude_posts_error_on_exception(monkeypatch):
    mock_client = MagicMock()
    mock_client.messages.create.side_effect = RuntimeError("API down")

    posted = []
    monkeypatch.setattr(slack_webhook.anthropic, "Anthropic", lambda **kwargs: mock_client)
    monkeypatch.setattr(slack_webhook.requests, "post", lambda url, json, timeout: posted.append(json))

    slack_webhook.run_claude("make status", "https://hooks.slack.com/test", "fake-key")

    assert len(posted) == 1
    assert "❌" in posted[0]["text"]
```

- [ ] **Step 2: 執行 run_claude 測試，確認 FAIL**

```bash
pytest tests/test_slack_webhook.py::test_run_claude_posts_result_to_slack \
       tests/test_slack_webhook.py::test_run_claude_executes_bash_tool \
       tests/test_slack_webhook.py::test_run_claude_posts_error_on_exception -v
```

Expected: 3 FAILED（NotImplementedError 或 ImportError）

- [ ] **Step 3: 在 scripts/slack_webhook.py 中加入剩餘 import（anthropic, requests, subprocess, Path）**

將頂端 import 區塊改為：

```python
import hashlib
import hmac as hmac_module
import os
import subprocess
import threading
import time
from pathlib import Path

import anthropic
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
```

- [ ] **Step 4: 在 create_app() 之前，加入 MODEL、TOOLS 常數與 run_bash、_post_to_slack 輔助函式**

```python
MODEL = "claude-sonnet-4-6"
TOOLS = [
    {
        "name": "bash",
        "description": "Execute a bash command in the k3s-istio-sandbox repo",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "The bash command to run"}
            },
            "required": ["command"],
        },
    }
]
REPO_DIR = Path(__file__).parent.parent


def run_bash(command: str) -> str:
    result = subprocess.run(
        command, shell=True, capture_output=True, text=True,
        cwd=str(REPO_DIR), timeout=300,
    )
    return (result.stdout + result.stderr)[:4000]


def _post_to_slack(response_url: str, text: str) -> None:
    requests.post(
        response_url,
        json={"response_type": "in_channel", "text": text},
        timeout=10,
    )
```

- [ ] **Step 5: 實作 run_claude（取代先前的 NotImplementedError 佔位）**

```python
def run_claude(user_message: str, response_url: str, anthropic_api_key: str) -> None:
    try:
        client = anthropic.Anthropic(api_key=anthropic_api_key)
        system_prompt = (Path(__file__).parent / "slack_webhook_system_prompt.txt").read_text()
        messages = [{"role": "user", "content": user_message}]

        response = client.messages.create(
            model=MODEL,
            max_tokens=4096,
            system=system_prompt,
            tools=TOOLS,
            messages=messages,
        )

        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use" and block.name == "bash":
                    output = run_bash(block.input["command"])
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": output,
                    })
            messages = messages + [
                {"role": "assistant", "content": response.content},
                {"role": "user", "content": tool_results},
            ]
            response = client.messages.create(
                model=MODEL,
                max_tokens=4096,
                system=system_prompt,
                tools=TOOLS,
                messages=messages,
            )

        result_text = "".join(
            block.text for block in response.content if hasattr(block, "text")
        ) or "✅ 完成（無輸出）"

        _post_to_slack(response_url, result_text)

    except Exception as exc:
        _post_to_slack(response_url, f"❌ 執行失敗：{exc}")
```

- [ ] **Step 6: 執行全部測試，確認 PASS**

```bash
pytest tests/test_slack_webhook.py -v
```

Expected: 9 PASSED

- [ ] **Step 7: Commit**

```bash
git add scripts/slack_webhook.py tests/test_slack_webhook.py
git commit -m "feat: implement Claude agentic loop with bash tool"
```

---

### Task 5: System Prompt 檔案

**Files:**
- Create: `scripts/slack_webhook_system_prompt.txt`

- [ ] **Step 1: 建立 scripts/slack_webhook_system_prompt.txt**

```
你是一個 k3s-istio-sandbox 環境操作助手，透過 Slack slash command 接收指令。

## 工作目錄

只能在 /userap/hb/git/k3s-istio-sandbox 目錄內執行操作。

## 允許的指令

- make status
- make install [ISTIO_VERSION=x.xx.x] [K3S_VERSION=vx.xx.x+k3s1]
- make install-k3s
- make install-istio
- make verify
- make verify-samples
- make clean-samples
- make uninstall
- make uninstall-istio
- make uninstall-k3s
- kubectl get / describe / logs（唯讀操作）
- istioctl analyze / version / proxy-status
- gh issue create / gh issue list / gh issue view

## 禁止的操作

- 修改 /userap/hb/git/k3s-istio-sandbox 以外的任何目錄或檔案
- 執行 rm -rf /、dd、mkfs 等破壞性指令
- 安裝或移除系統套件（apt, yum 等）
- 任何與 k3s-istio-sandbox 無關的操作

## 回應格式

- 使用繁體中文
- 簡明摘要操作結果（不超過 500 字）
- 成功以 ✅ 開頭，失敗以 ❌ 開頭
- 若有建立 GitHub Issue，附上 issue URL
- 若操作耗時較長，說明已完成的步驟
```

- [ ] **Step 2: 確認 run_claude 能讀取到系統提示**

```bash
python3 -c "
from pathlib import Path
import sys; sys.path.insert(0, 'scripts')
p = Path('scripts/slack_webhook_system_prompt.txt')
print('OK, length:', len(p.read_text()))
"
```

Expected: `OK, length: <數字>`

- [ ] **Step 3: Commit**

```bash
git add scripts/slack_webhook_system_prompt.txt
git commit -m "feat: add Claude system prompt for k3s-istio-sandbox scope"
```

---

### Task 6: Makefile targets（serve / serve-stop / test）

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: 在 Makefile 第 1 行的 .PHONY 清單中加入新 targets**

將：
```makefile
.PHONY: help install install-k3s install-istio status verify verify-samples clean-samples uninstall uninstall-istio uninstall-k3s
```
改為：
```makefile
.PHONY: help install install-k3s install-istio status verify verify-samples clean-samples uninstall uninstall-istio uninstall-k3s serve serve-stop test
```

- [ ] **Step 2: 在 Makefile 的 `uninstall-k3s` target 後加入新 targets**

```makefile
serve:
	@[ -f .env ] || (echo "Error: .env not found. Copy .env.example and fill in values." && exit 1)
	nohup python3 scripts/slack_webhook.py > /tmp/slack-webhook.log 2>&1 & echo $$! > /tmp/slack-webhook.pid
	@echo "Webhook server started (PID $$(cat /tmp/slack-webhook.pid)). Log: /tmp/slack-webhook.log"

serve-stop:
	@[ -f /tmp/slack-webhook.pid ] && kill $$(cat /tmp/slack-webhook.pid) && rm /tmp/slack-webhook.pid && echo "Server stopped" || echo "Server not running"

test:
	pytest tests/ -v
```

- [ ] **Step 3: 也更新 help target，在說明末尾加入新指令說明**

在現有 `@echo "  make uninstall-k3s   Remove k3s only"` 之後加入：

```makefile
	@echo "  make serve             Start Slack webhook server (requires .env)"
	@echo "  make serve-stop        Stop Slack webhook server"
	@echo "  make test              Run all tests"
```

- [ ] **Step 4: 驗證 make test 能跑通**

```bash
make test
```

Expected: 9 PASSED，exit code 0

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: add serve, serve-stop, test targets to Makefile"
```

---

### Task 7: README 更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 在 README.md 末尾加入 Slack Integration 段落**

在現有內容末尾加入（不改動現有內容）：

```markdown
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
```

- [ ] **Step 2: 確認 README 語法正確**

```bash
python3 -c "
with open('README.md') as f:
    content = f.read()
print('README lines:', content.count(chr(10)))
print('OK')
"
```

Expected: 印出行數與 `OK`

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Slack Integration section to README"
```

---

## 完成驗證

所有 task 完成後執行：

```bash
make test
```

Expected：9 PASSED，exit code 0。

```bash
git log --oneline main..HEAD
```

Expected：7 commits 顯示在 feature branch 上。
