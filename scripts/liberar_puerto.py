#!/usr/bin/env python3
"""Libera el puerto local matando procesos en estado LISTENING."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time


def pids_on_port(port: int) -> set[int]:
    try:
        out = subprocess.check_output(
            ["netstat", "-ano"],
            text=True,
            encoding="utf-8",
            errors="ignore",
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR netstat: {exc}", file=sys.stderr)
        return set()

    pids: set[int] = set()
    needle = f":{port}"
    for line in out.splitlines():
        if needle not in line or "LISTENING" not in line.upper():
            continue
        parts = line.split()
        if not parts:
            continue
        try:
            pid = int(parts[-1])
        except ValueError:
            continue
        if pid > 0:
            pids.add(pid)
    return pids


def kill_pids(pids: set[int]) -> list[int]:
    killed: list[int] = []
    me = os.getpid()
    for pid in sorted(pids):
        if pid == me:
            continue
        print(f"  Matando PID {pid}...")
        rc = subprocess.call(
            ["taskkill", "/F", "/PID", str(pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if rc == 0:
            killed.append(pid)
    return killed


def free_port(port: int, retries: int = 5) -> bool:
    for attempt in range(retries):
        pids = pids_on_port(port)
        if not pids:
            return True
        if attempt == 0:
            print(f"Puerto {port} ocupado por: {', '.join(str(p) for p in sorted(pids))}")
        kill_pids(pids)
        time.sleep(0.5)
    remaining = pids_on_port(port)
    if remaining:
        print(
            f"ERROR: el puerto {port} sigue ocupado (PID: {', '.join(str(p) for p in sorted(remaining))})",
            file=sys.stderr,
        )
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Libera un puerto TCP local")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    ok = free_port(args.port)
    if ok:
        print(f"Puerto {args.port} libre.")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
