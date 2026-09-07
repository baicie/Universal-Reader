#!/usr/bin/env python3
"""Fix the appended library_controller_test.dart so main() is closed properly."""
from pathlib import Path

OUT = Path(r"D:/workspace/git-code/Universal-Reader/app/test/library_controller_test.dart")

b = OUT.read_bytes()
text = b.decode("utf-8")
text_lf = text.replace("\r\n", "\n")

# We appended three groups but lost the closing `}` of main().
# Insert a final `}` after the last `});` at end-of-file.
if not text_lf.rstrip().endswith("}"):
    # Append a closing brace on a new line.
    new_text_lf = text_lf.rstrip() + "\n}\n"
    new_text = new_text_lf.replace("\n", "\r\n")
    OUT.write_bytes(new_text.encode("utf-8"))
    print(f"appended closing brace; size {len(b)} -> {len(new_text)}")
else:
    print("file already ends with `}`")
