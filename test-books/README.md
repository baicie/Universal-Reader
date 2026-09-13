# Compatibility Corpus

This directory contains one minimal, synthetic book for every main format:
EPUB, PDF, MOBI, AZW3, FB2, TXT, Markdown, HTML, DOCX, ODT, CBZ, and CBR.

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
