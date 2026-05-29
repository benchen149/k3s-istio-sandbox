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
