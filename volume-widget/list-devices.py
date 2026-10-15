#!/usr/bin/env python3
"""List PulseAudio-compatible devices for the Awesome volume menu."""

import json
import re
import subprocess
import sys


def pactl(*args):
    return subprocess.run(
        ["pactl", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def clean(value):
    return str(value or "").replace("\t", " ").replace("\r", " ").replace("\n", " ")


def volume_percent(device):
    values = []
    for channel in (device.get("volume") or {}).values():
        percent = channel.get("value_percent", "")
        match = re.search(r"\d+(?:\.\d+)?", str(percent))
        if match:
            values.append(float(match.group(0)))
    return round(sum(values) / len(values)) if values else 0


def main():
    sinks = json.loads(pactl("-f", "json", "list", "sinks"))
    sources = json.loads(pactl("-f", "json", "list", "sources"))
    default_sink = pactl("get-default-sink")
    default_source = pactl("get-default-source")

    print("SINKS")
    for device in sinks:
        name = clean(device.get("name"))
        description = clean(device.get("description") or name)
        print(f"{name}\t{description}\t{int(name == default_sink)}\t{volume_percent(device)}")

    print("SOURCES")
    for device in sources:
        name = clean(device.get("name"))
        description = clean(device.get("description") or name)
        print(f"{name}\t{description}\t{int(name == default_source)}\t{volume_percent(device)}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"Could not read audio devices: {error}", file=sys.stderr)
        sys.exit(1)
