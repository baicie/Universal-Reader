# Changelog

## Unreleased

- Reading settings for line height, body font, and paper (match app / light / dark) reach the Foliate host and the text fallback.

## 0.0.1-dev.11 - 2026-08-29

- Favorites and collections persist per library: starring a book, creating a collection, and opening a collection only show those books. Seed titles are not used as fake favorites.
- An empty local library stays empty instead of writing seed books. A book can be removed from the shelf without inventing another title.
- The local server keeps the document list in SQLite. An existing `catalog.json` is imported once and is not the catalog after that.
- Imported EPUB and FB2 books use the title and author from the file. TXT and files without metadata keep the file name and an empty author.
- Questions and answers live in SQLite. Existing `conversations/{id}.json` files are imported once and are not the store after that.
- The Foliate host uses the reading font size from settings.

## 0.0.1-dev.10 - 2026-08-29

- EPUB and simple text PDFs open as real chapters/pages instead of the unavailable placeholder; corrupt files stay corrupt.
- The local server keeps the catalog in SQLite with FTS5, can scan a folder or import from a configured WebDAV location, and can search one book by locator.
- The assistant can ask the current book (not just the current excerpt), suggest a jump the user must confirm, talk to Ollama, and save a turn as a note.
- Reflow books open through an isolated Foliate WebView host (tests keep the chapter text), PDFs through an isolated pdfrx page, and CBZ/CBR as comic pages. MOBI/AZW3/FB2 have engines.
- Without Rust, Flutter keeps the library in SQLite so imported files still open after a restart. Web uses the same repository interface with durable local storage.
- Notes paint their quote in the current chapter. The server hashes files, extracts covers, can watch a folder, and can sync WebDAV both ways.
- The reader can save a text selection as a user note, keep bookmarks on the same annotation store, and paginate reflow chapters through a testable Foliate session with CFI.
- Notes and bookmarks can be listed and deleted per book without touching the conversation. In-book search jumps through the current document only.

## 0.0.1-dev.9 - 2026-08-29

- The reading assistant now uses DeepSeek (`deepseek-chat` / `deepseek-reasoner`), with endpoint, model, and optional API key configurable in Settings or project `--dart-define` values.
- Questions and answers are remembered per book (on-device, or in `conversations/` when using the local server).
- The Rust service can forward DeepSeek chat requests and store conversation logs; it does not run a second reading agent.

## 0.0.1-dev.8 - 2026-08-29

- The reader now opens imported TXT, Markdown, and HTML files instead of a placeholder chapter.
- Reading settings adjust body font size and remember it on this device.

## 0.0.1-dev.7 - 2026-08-28

- Added an optional, off-by-default reading assistant that sends only the current excerpt to a user-configured OpenAI-compatible endpoint.
- The Rust server can serve a Flutter web build from `web/` next to the binary (or `UNIVERSAL_READER_WEB_DIR`), with SPA fallback while keeping `/health` and `/v1/*` as APIs.
- Release now ships combined web + server archives for Linux and Windows; `UNIVERSAL_READER_SERVER_BIND` selects the listen address (`127.0.0.1` by default).
- The Rust service now stores books as a simple on-disk drive (`files/` + `catalog.json`) with list/upload/download/progress/delete APIs; the Flutter app uses that store when the service is reachable.
- The Flutter app is localized with Chinese as the default and fallback; English and follow-system are available in Settings.

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
