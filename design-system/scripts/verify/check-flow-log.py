#!/usr/bin/env python3
"""Check that a recorded v6 flow completed every step without skipping."""

import argparse
from pathlib import Path
import re
import sys


def failures(text: str, expected: int) -> list[str]:
    lines = [line for line in text.splitlines() if not line.startswith("Filtering ")]
    messages = [line.split("[cameo] ", 1)[1] for line in lines if "[cameo] " in line]
    steps = [
        match.groups()
        for message in messages
        if (match := re.fullmatch(r"flow demo: (\d+)/(\d+) '([^']+)' → (\w+)", message))
    ]
    errors = []
    if [int(step[0]) for step in steps] != list(range(1, expected + 1)):
        errors.append(f"expected steps 1–{expected} exactly once; found {len(steps)} step records")
    if any(int(step[1]) != expected for step in steps):
        errors.append(f"the recorded flow does not use {expected} steps")
    if not steps or steps[0][2:] != ("welcome.start", "phone"):
        errors.append("the flow did not start with welcome.start → phone")
    if not steps or steps[-1][2:] != ("sheet.confirm", "welcome"):
        errors.append("the flow did not finish with sheet.confirm → welcome")
    if "flow demo: 시작" not in messages or "flow demo: 끝" not in messages:
        errors.append("the start or completion marker is missing")
    if any(re.search(r"pending|건너뛴|멈춘다|받지 않았다", message) for message in messages):
        errors.append("the flow reported a skipped, refused or timed-out step")
    if any(re.search(r"\bUnhandled\b|\bSIGABRT\b|\bSIGSEGV\b|\babort\b", line, re.I) for line in lines):
        errors.append("the recording contains an unhandled exception or abort")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--steps", type=int, default=40)
    args = parser.parse_args()
    if args.steps < 1:
        parser.error("--steps must be positive")
    try:
        errors = failures(args.log.read_text(encoding="utf-8"), args.steps)
    except (OSError, UnicodeError) as error:
        parser.error(str(error))
    if errors:
        for error in errors:
            print(f"flow check failed: {error}", file=sys.stderr)
        return 1
    print(f"flow verified: {args.steps}/{args.steps}, welcome → welcome, no skipped steps, unhandled exceptions or aborts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
