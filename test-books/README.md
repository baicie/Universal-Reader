# Compatibility Corpus

This directory contains one minimal, synthetic book for every main format:
EPUB, PDF, MOBI, AZW3, FB2, TXT, Markdown, HTML, DOCX, ODT, RTF, DjVu, CHM, CBT, CB7, CBZ, and CBR.

The corpus exists for import, format detection, reader-engine, and release
smoke tests. It is intentionally tiny and deterministic. Regenerate it from
the Flutter project with:

```powershell
cd app
dart run tool/generate_test_books.dart
```

`manifest.json` records each file's format, byte size, and SHA-256 digest.
The CBR sample is derived from the MIT-licensed `koni_archive` synthetic comic
fixture. All other files are generated from project-owned test fixture code.
The CHM sample is generated with the MIT-licensed RustChm compiler and is
currently converted to EPUB by the local Rust service before reading.
The DjVu sample is generated with the MIT-licensed `djvu-rs` encoder and is
converted to CBZ by the Rust service before reading.
