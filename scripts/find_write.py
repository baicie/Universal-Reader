#!/usr/bin/env python3
"""Find the Write tool call for library_controller_test.dart and dump its contents."""
import json, sys
from pathlib import Path

TRANSCRIPT = Path(sys.argv[1])
for i, line in enumerate(TRANSCRIPT.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
    if not line.strip():
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
        if blk.get("type") == "tool_use" and blk.get("name") == "Write":
            inp = blk.get("input") or {}
            p = inp.get("path", "")
            if "library_controller_test" in p:
                sys.stdout.write(f"=== line {i} | Write | {p} ===\n")
                sys.stdout.write(inp.get("contents", ""))
                sys.stdout.write("\n=== END ===\n")
