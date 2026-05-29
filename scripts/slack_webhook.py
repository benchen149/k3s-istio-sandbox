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
