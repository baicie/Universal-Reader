import json, sys
from pathlib import Path

TRANSCRIPT = Path(sys.argv[1])
hits = []
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
                hits.append((i, p, inp.get("contents", "")))

for (i, p, c) in hits:
    print(f"=== line {i} | Write | {p} | {len(c)} chars ===")
print(f"total writes: {len(hits)}")
