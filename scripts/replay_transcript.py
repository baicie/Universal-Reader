#!/usr/bin/env python3
"""Reconstruct the final state of library_controller_test.dart by replaying
all StrReplace operations in transcript order, starting from HEAD."""
import json
import re
import sys
import subprocess
from pathlib import Path

TRANSCRIPT = Path(sys.argv[1])
REPO = Path(sys.argv[2])
REL = "app/test/library_controller_test.dart"
OUT = REPO / REL

# 1) Reset file to HEAD.
res = subprocess.run(
    ["git", "-C", str(REPO), "show", f"HEAD:{REL}"],
    capture_output=True,
    check=True,
)
HEAD_BYTES = res.stdout
current = HEAD_BYTES.decode("utf-8", errors="replace")

# 2) Replay all StrReplace ops for this file.
def parse_transcript():
    for line in TRANSCRIPT.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        msg = rec.get("message") or {}
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for blk in content:
            if not isinstance(blk, dict):
                continue
            if blk.get("type") != "tool_use":
                continue
            if blk.get("name") != "StrReplace":
                continue
            inp = blk.get("input") or {}
            target = inp.get("path", "").replace("/", "\\").lower()
            wanted = REL.replace("/", "\\").lower()
            if not target.endswith(wanted):
                continue
            yield inp

ops = list(parse_transcript())
print(f"replaying {len(ops)} ops")

for i, op in enumerate(ops, 1):
    old = op["old_string"]
    new = op["new_string"]
    replace_all = bool(op.get("replace_all"))
    # Normalize line endings to LF for matching.
    haystack = current
    needle = old
    if needle not in haystack:
        # Try CRLF normalization on needle.
        needle_crlf = needle.replace("\r\n", "\n").replace("\n", "\r\n")
        if needle_crlf in haystack:
            needle = needle_crlf
        else:
            # Try stripping trailing whitespace per line.
            def strip(t):
                return "\n".join(re.sub(r"[ \t]+$", "", l) for l in t.split("\n"))
            if strip(needle) in strip(haystack):
                needle = strip(needle)
            else:
                print(f"!! step {i}: old_string not found (len={len(needle)}); preview:")
                print(needle[:200])
                sys.exit(2)
    count = haystack.count(needle)
    if not replace_all and count != 1:
        print(f"!! step {i}: old_string found {count} times (need 1 or replace_all=True)")
        sys.exit(3)
    current = haystack.replace(needle, new, -1 if replace_all else 1)
    print(f"step {i}: replaced ({len(old)} -> {len(new)} bytes)")

OUT.write_text(current, encoding="utf-8")
print(f"final size: {len(current)} bytes -> {OUT}")
