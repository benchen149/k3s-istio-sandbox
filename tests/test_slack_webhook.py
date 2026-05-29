import hashlib
import hmac as hmac_module
import time
import importlib
from unittest.mock import patch

import pytest
from slack_webhook import verify_slack_signature
import slack_webhook as sw


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


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("SLACK_SIGNING_SECRET", SECRET)
    monkeypatch.setenv("SLACK_BOT_TOKEN", "xoxb-test")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
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
