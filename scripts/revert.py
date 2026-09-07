#!/usr/bin/env python3
"""Revert the bad append: strip everything from line 376 onward, keeping only the
original main() close."""
from pathlib import Path

OUT = Path(r"D:/workspace/git-code/Universal-Reader/app/test/library_controller_test.dart")
b = OUT.read_bytes()
text = b.decode("utf-8")
text_lf = text.replace("\r\n", "\n")
lines = text_lf.split("\n")

# Line 375 (1-indexed) is '}' closing main. We keep 1..375 and discard the rest.
KEEP = 375
new_text_lf = "\n".join(lines[:KEEP]) + "\n"
new_text = new_text_lf.replace("\n", "\r\n")
OUT.write_bytes(new_text.encode("utf-8"))
print(f"reverted; size {len(b)} -> {len(new_text)}; kept lines 1..{KEEP}")
