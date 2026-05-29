import hashlib
import hmac as hmac_module
import time
import os
import threading

from dotenv import load_dotenv
from flask import Flask, jsonify, request


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


def run_claude(user_message: str, response_url: str, anthropic_api_key: str) -> None:
    raise NotImplementedError


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
