# Changelog

## Unreleased

- Reading settings for line height, body font, and paper (match app / light / dark) reach the Foliate host and the text fallback.
- Imported GBK/GB18030 TXT and Markdown decode as Chinese instead of replacement characters. Bytes that are neither UTF-8 nor GB18030 stay corrupt.
- Shelf titles and authors can be renamed in the catalog. An empty title keeps the previous name; a missing book is not invented.
- Comic reading supports single page, double page, vertical scroll, and right-to-left. An odd last page stands alone; a missing neighbor is not filled from another book.
- EPUB / MOBI / AZW3 / FB2 paginate in the reader: tap the right edge or press the right arrow for the next page, then the next chapter. The progress slider lands on a page. The last page does not wrap to another book.
- EPUB chapter HTML keeps images and chapter CSS. The Foliate host lays the chapter out with a local `paginator.js`, not a CDN. Missing images stay missing. `srcset` (including `<picture><source>`), SVG `<image href>` / `xlink:href`, `<object data>`, `<embed src>`, and `<video poster>` are inlined the same way as `src`; a missing or `https` candidate stays. `<script>` tags and `on*` event attributes are removed and are not executed.
- FB2 chapter `<image l:href="#id">` becomes an `<img>` data URI from that file's `binary`. A missing binary stays missing; a cover binary is not inserted into a chapter that does not reference it. FB2 `<emphasis>` and `<strong>` stay as `<em>` and `<strong>` in chapter HTML. `<strikethrough>` stays as `<s>`. `<sub>` and `<sup>` stay as `<sub>` and `<sup>`. `<code>` stays as `<code>`. `<a l:href="#id">` stays as `<a href="#id">`; a section `id` is copied onto the chapter `<section>`. When that id belongs to another chapter, the href becomes `section-N#id`. Paragraph `id` and empty `<a id>` anchors are copied the same way. An `https` / `mailto` href keeps the link text and is not opened. `<empty-line/>` becomes a blank paragraph; `<subtitle>` becomes `<h2>` and is searchable. A `<poem>` keeps verse lines with breaks in chapter HTML; a poem-only section still opens. An epigraph nested in a poem stays in that poem. A poem `<subtitle>` stays as `<h4>`. A poem `<text-author>` stays in that poem. A poem `<date>` stays in that poem; an empty date uses its `value` attribute. A stanza `<title>` / `<subtitle>` stays as `<h4>` / `<h5>`. A section `<table>` becomes an HTML table; a table `<title>` becomes `<caption>`; a positive `colspan` / `rowspan` is copied onto the cell; `align` (`left` / `right` / `center`) and `valign` (`top` / `middle` / `bottom`) are copied the same way; an empty table is omitted and a table-only section still opens. `<epigraph>` and `<cite>` become `<blockquote>` (paragraphs, subtitle, empty-line, text-author, poem, table, and a nested cite) and are searchable. A section `<annotation>` becomes an `<aside>` (paragraphs, subtitle, empty-line, cite, poem, and table); an empty annotation is omitted and an annotation-only section still opens.
- FB2 shelf covers follow the `title-info` coverpage image href on both Flutter import and the local Rust service. A missing coverpage, `https` href, or unmatched binary stays without a cover; a chapter binary whose id contains `cover` is not used as the cover.
- A FB2 `title-info` annotation becomes the first TOC chapter (`annotation`) using the same aside HTML as a section annotation. An empty annotation or a `src-title-info` annotation does not add a chapter; body sections still use `section-0`.
- FB2 nested sections appear under their titled parent in the TOC. An untitled wrapper section is omitted; tapping a child still opens that child's href.
- FB2 `body name="notes"` and `name="comments"` sections stay readable with the same `section-N` hrefs, and appear as separate TOC groups after the main text. An empty notes body or an unnamed second body does not add a group.
- An FB2 main `body` without `<section>` still opens: its direct blocks become `section-0` (and later bodies keep document order). A body that already has sections does not also emit leftover body-level paragraphs. An empty body or a notes-only body without sections stays corrupt.
- The reader TOC current item follows the open chapter href (and EPUB fragment). Nested FB2 books highlight the child and show the chapter count in the chrome instead of the top-level TOC length.
- Embedded EPUB fonts in chapter CSS `url()` become `data:` URIs. A missing font file keeps its path.
- Chapter CSS `@import` without a media query is replaced with that file, then `url()` is inlined. A missing or `https` import stays; a circular import does not hang.
- Reflow page turns and progress follow viewport pages reported by the Foliate host. Tests without a WebView still use character pages.
- Note quotes are painted in the Foliate chapter HTML. A missing quote is not filled from another book; bookmarks are not highlights.
- In-chapter EPUB links jump inside the current book. External `http` / `mailto` hrefs are ignored; a missing chapter stays on the current one.
- In-chapter `#id` links scroll to that element. A missing id stays on the current page.
- EPUB3 nav nested entries show under the spine chapter with a fragment. A nav href outside the spine is not a new chapter. Tapping a subsection scrolls to that id.
- Tapping a note scrolls to that note's quote. An empty quote only jumps to the locator; a missing locator does not jump.
- In-book search hits scroll to the query. A missing sentence stays at the start of the chapter.
- Reflow tap and arrow keys push a captured page index to the Foliate host. The chrome shows the page in the chapter, not the chapter count as a page count.
- PDF pages can be zoomed from reading settings (100%–300%). The page fills the reading surface instead of the reflow column. Tests still show page text, not a sample chapter.

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
