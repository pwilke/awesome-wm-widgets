#!/usr/bin/env python3
"""Print network interface receive/transmit counters from sysfs."""

from pathlib import Path


def read_counter(path):
    try:
        return int(path.read_text().strip())
    except (OSError, ValueError):
        return None


for interface_dir in sorted(Path("/sys/class/net").iterdir()):
    statistics = interface_dir / "statistics"
    rx = read_counter(statistics / "rx_bytes")
    tx = read_counter(statistics / "tx_bytes")
    if rx is not None and tx is not None:
        print(f"{interface_dir.name}\t{rx}\t{tx}")
