# Changelog

## 0.0.1-dev.2 - 2026-08-25

- Added local Rust multipart upload endpoint at `/v1/library/files`.
- Restricted uploads to supported reading formats with a 64 MiB size limit.
- Stored imported files under a controlled library directory using generated safe names.
- Removed the obsolete root-level static prototype and aligned the README with the Flutter app.

## 0.0.1-dev.1 - 2026-08-25

- Added `universal-reader-server`, a Rust local backend service for health reporting and first-pass document format detection.
- Added CI quality gates for Rust formatting, Clippy, tests, and release builds.
- Release artifacts now include Linux and Windows Rust service packages.

## 0.0.1-dev.0 - 2026-08-25

Initial development release.

- Flutter Library, Reader, and Settings shell based on the design document.
- Local-first library persistence through SharedPreferences.
- File import and first-pass format detection for EPUB, PDF, MOBI, AZW3, FB2, TXT, Markdown, HTML, CBZ, and CBR.
- Reader Runtime contracts for documents, renderers, adapters, locators, ranges, search, and progress.
- GitHub Actions quality gates and Web/Windows release packaging.
