import json, sys
from pathlib import Path

TRANSCRIPT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
for line in TRANSCRIPT.read_text(encoding="utf-8", errors="replace").splitlines():
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
                OUT.write_text(inp.get("contents", ""), encoding="utf-8")
                print(f"wrote {len(inp.get('contents',''))} chars to {OUT}")
