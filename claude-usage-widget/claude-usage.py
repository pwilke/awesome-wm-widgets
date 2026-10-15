#!/usr/bin/env python3
"""Read Claude quota windows cached by the Claude Code statusline script."""

import json
import os
import sys
import time
from datetime import datetime

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "claude-usage.json")


def format_window(window, now):
    if not window or window.get("used_percentage") is None:
        return "--\t--"
    reset = window.get("resets_at")
    if reset and reset <= now:
        # The window rolled over since the cache was written
        return "100\treset"
    remaining = max(0, min(100, 100 - round(window["used_percentage"])))
    if reset:
        reset_text = datetime.fromtimestamp(reset).astimezone().strftime("%a %H:%M")
        return f"{remaining}\t{reset_text}"
    return f"{remaining}\t--"


def format_age(seconds):
    if seconds < 120:
        return "just now"
    if seconds < 7200:
        return f"{seconds // 60} min ago"
    if seconds < 172800:
        return f"{seconds // 3600} h ago"
    return f"{seconds // 86400} days ago"


def main():
    now = time.time()
    with open(CACHE) as f:
        limits = json.load(f)
    age = format_age(int(now - os.path.getmtime(CACHE)))
    print("\t".join((
        format_window(limits.get("five_hour"), now),
        format_window(limits.get("seven_day"), now),
        age,
    )))


if __name__ == "__main__":
    try:
        main()
    except FileNotFoundError:
        print("No Claude usage cached yet: run Claude Code once")
        sys.exit(1)
    except Exception as error:
        print(f"Claude usage error: {error}")
        sys.exit(1)
