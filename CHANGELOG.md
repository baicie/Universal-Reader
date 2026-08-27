# Changelog

## Unreleased

## 0.0.1-dev.6 - 2026-08-27

- Configured the Intel macOS build to exclude arm64 before Universal app assembly.

## 0.0.1-dev.5 - 2026-08-27

- Fixed desktop release validation so Linux archives do not fail from an early-closed verification pipeline.
- Built and verified separate macOS arm64 and x86_64 binaries before creating the Universal installer.
- Uploaded the Windows x86_64 Inno Setup installer with the other Windows release artifacts.

## 0.0.1-dev.4 - 2026-08-26

- Windows release artifacts now include a ZIP package and an x86_64 Inno Setup `.exe` installer.
- macOS release artifacts now include Universal, arm64, and x86_64 `.dmg` installers plus matching archives.

## 0.0.1-dev.3 - 2026-08-25

- Release artifacts now provide a platform-level package plus an explicit architecture package; Android also includes arm64-v8a, armeabi-v7a, and x86_64 APKs.

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
