#!/usr/bin/env python3
"""Extract every `Write` and `StrReplace` new_string content from a JSONL transcript
and dump them in order, so we can reconstruct the lost file step by step."""
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
out = out_path.open("w", encoding="utf-8")
i = 0
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
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
        btype = blk.get("type")
        if btype == "tool_use":
            name = blk.get("name")
            if name in ("Write", "StrReplace"):
                inp = blk.get("input") or {}
                ns = inp.get("new_string")
                target = inp.get("path", "?")
                if ns:
                    out.write(f"\n===== STEP {i} | {name} | {target} =====\n")
                    out.write(ns)
                    out.write("\n")
                    i += 1
print(f"wrote {i} steps to {out_path}")
