import hashlib
import hmac as hmac_module
import time


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
