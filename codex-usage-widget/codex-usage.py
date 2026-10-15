#!/usr/bin/env python3
"""Read Codex quota windows through the local app-server protocol."""

import json
import subprocess
import sys


def request(process, request_id, method, params):
    process.stdin.write(json.dumps({"id": request_id, "method": method, "params": params}) + "\n")
    process.stdin.flush()
    while True:
        line = process.stdout.readline()
        if not line:
            raise RuntimeError("Codex app-server closed the connection")
        message = json.loads(line)
        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError(message["error"].get("message", "Codex request failed"))
            return message.get("result", {})


def format_window(window):
    if not window:
        return "--\t--"
    remaining = max(0, min(100, 100 - round(window["usedPercent"])))
    reset = window.get("resetsAt")
    if reset:
        from datetime import datetime

        reset_text = datetime.fromtimestamp(reset).astimezone().strftime("%a %H:%M")
        return f"{remaining}\t{reset_text}"
    return f"{remaining}\t--"


def main():
    process = subprocess.Popen(
        ["/home/pwilke/.npm-global/bin/codex", "app-server", "--listen", "stdio://"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    try:
        request(process, 1, "initialize", {
            "clientInfo": {"name": "awesomewm-usage-widget", "title": "AwesomeWM usage", "version": "1.0.0"},
            "capabilities": {},
        })
        process.stdin.write(json.dumps({"method": "initialized", "params": {}}) + "\n")
        process.stdin.flush()
        data = request(process, 2, "account/rateLimits/read", {"excludeResetCreditDetails": True})
        limits = data.get("rateLimitsByLimitId") or {}
        quota = limits.get("codex") or data.get("rateLimits") or {}
        print("\t".join((format_window(quota.get("primary")), format_window(quota.get("secondary")))))
    finally:
        process.kill()
        process.wait(timeout=2)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Codex usage error: {error}")
        sys.exit(1)
