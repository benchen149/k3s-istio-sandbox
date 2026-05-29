# Slack → Claude Code Trigger Design

## Goal

Enable a `/claude <message>` Slack slash command to automatically trigger Claude Code on the cloud VM, execute k3s-istio-sandbox operations (install, test, issue creation), and post results back to the originating Slack thread — with no manual intervention.

## Architecture

```
Slack                  Cloud VM (demo)                  External
─────                  ───────────────                  ────────
/claude <message>
    │ HTTP POST
    ▼
[slack-webhook server]     scripts/slack-webhook.py
    │ HTTP 200 immediately  "⏳ 處理中，請稍候..."
    │
    ├─ verify Slack HMAC signature
    │
    └─ background thread
              │
              ▼
        [Claude API]        claude-sonnet-4-6
              │  system prompt + bash tool
              ├─ make status
              ├─ make install ISTIO_VERSION=x.xx.x
              ├─ kubectl / istioctl commands
              ├─ gh issue create
              │
              └─ Slack API  →  post result to thread
```

## Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `scripts/slack-webhook.py` | VM | Flask server receiving Slack slash commands |
| `scripts/slack-webhook-system-prompt.txt` | VM | System prompt defining Claude's allowed scope |
| `.env` | VM root (not committed) | SLACK_SIGNING_SECRET, SLACK_BOT_TOKEN, ANTHROPIC_API_KEY |
| `make serve` | Makefile | Start webhook server |
| `make serve-stop` | Makefile | Stop webhook server |
| Slack App | api.slack.com | `/claude` slash command → VM public endpoint |

## Data Flow

1. User types `/claude 請幫我測試 istio 1.29.2 的 sidecar injection` in Slack
2. Slack sends `POST /slack/command` to the VM webhook URL with:
   - `command=/claude`
   - `text=<user message>`
   - `channel_id`, `user_id`, `response_url`
3. Webhook server:
   - Verifies `X-Slack-Signature` via HMAC-SHA256 (rejects if invalid → HTTP 403)
   - Responds HTTP 200 immediately with `⏳ 處理中，請稍候...`
   - Spawns background thread calling Claude API
4. Claude API (with bash tool):
   - Interprets the user's request
   - Executes commands: `make status`, `make install ISTIO_VERSION=...`, `kubectl`, `gh issue create`, etc.
   - Collects all output and summarises
5. Webhook posts result to Slack via `response_url`:
   ```
   ✅ 環境就緒：k3s v1.33.1 + Istio 1.29.2
   📋 sidecar injection 測試通過
   🔗 Issue #4：https://github.com/benchen149/k3s-istio-sandbox/issues/4
   ```

## Security

| Concern | Approach |
|---------|----------|
| Request authenticity | Verify `X-Slack-Signature` HMAC-SHA256 on every request; reject if invalid or timestamp >5 min old |
| Secret management | `.env` on VM, never committed; `.gitignore` entry enforced |
| Claude scope | System prompt restricts Claude to operate only within `/userap/hb/git/k3s-istio-sandbox` |
| Slack Bot token scope | Minimum: `commands` + `chat:write` |

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| `make install` fails | Post stderr summary to Slack; do not silently swallow errors |
| Claude API timeout (>120s) | Post timeout error message to Slack via `response_url` |
| Invalid Slack signature | HTTP 403; no response to Slack |
| Claude produces no usable output | Post generic failure message with raw output attached |

## File Changes

- `scripts/slack-webhook.py` — new: Flask webhook server (~120 lines)
- `scripts/slack-webhook-system-prompt.txt` — new: Claude system prompt
- `.env.example` — new: template showing required env vars (no real values)
- `Makefile` — add `serve` and `serve-stop` targets
- `.gitignore` — add `.env`
- `README.md` — add Slack Integration section

## Slack App Setup (manual, one-time)

1. Create app at https://api.slack.com/apps → "From scratch"
2. **Slash Commands** → Create `/claude` → Request URL: `https://<VM_IP>:<PORT>/slack/command`
3. **OAuth & Permissions** → Bot Token Scopes: `commands`, `chat:write`
4. Install app to workspace → copy Bot Token → save to `.env`
5. **Basic Information** → Signing Secret → save to `.env`

## Dependencies

```
flask>=3.0
anthropic>=0.40
python-dotenv>=1.0
```

Install: `pip install flask anthropic python-dotenv`
