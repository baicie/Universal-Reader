# Changelog

## 0.0.1-dev.12 - 2026-08-31

### Test Coverage Improvements
- Enhanced MOBI document test coverage from 50% to 100% (42/84 → 84/84 lines)
  - Added comprehensive API tests for chapter navigation, locators, text extraction, search, and TOC
  - Added boundary tests for unknown hrefs, empty queries, single chapter progress, and index limits
  - Added format-specific tests for ZIP offset detection, HTML entity escaping, and readable text filtering
- Enhanced Comic document test coverage from 57.7% to 100% (30/52 → 52/52 lines)
  - Added comprehensive API tests for page navigation, locators, text extraction, search, and TOC
  - Added boundary tests for progress clamping, page range validation, and unsupported locator types
  - Added format-specific tests for case-insensitive sorting, nested directory handling, non-image filtering, and empty archive detection
- Total test count increased from 443 to 483 tests (+40 tests)

### Documentation
- Added comprehensive inline comments to `host.html` explaining Foliate integration, message protocol, and CFI calculation
- Documented CFI calculation logic and current usage in `docs/cfi-logic.md`
- Created `docs/README.md` as documentation index linking all technical documentation
- Enhanced renderer architecture documentation with detailed component descriptions

### Code Health
- Documented empty catch blocks with reasons (EOF on stream close, missing binary fallback, circular import break)
- Extracted duplicate "create and persist document" logic to `_createAndPersist` helper
- Added boundary tests for library controller (duplicate IDs, missing documents, corrupt files)
- Optimized `didUpdateWidget` to compare href only instead of full HTML content

### Performance
- Reduced unnecessary widget rebuilds in `IsolatedFoliateView` by avoiding expensive HTML string comparison

## Unreleased

- Reading settings for line height, body font, and paper (match app / light / dark) reach the Foliate host and the text fallback.
- Imported GBK/GB18030 TXT and Markdown decode as Chinese instead of replacement characters. Bytes that are neither UTF-8 nor GB18030 stay corrupt.
- Shelf titles and authors can be renamed in the catalog. An empty title keeps the previous name; a missing book is not invented.
- Comic reading supports single page, double page, vertical scroll, and right-to-left. An odd last page stands alone; a missing neighbor is not filled from another book.
- EPUB / MOBI / AZW3 / FB2 paginate in the reader: tap the right edge or press the right arrow for the next page, then the next chapter. The progress slider lands on a page. The last page does not wrap to another book.
- EPUB chapter HTML keeps images and chapter CSS. The Foliate host lays the chapter out with a local `paginator.js`, not a CDN. Missing images stay missing. `srcset` (including `<picture><source>`), SVG `<image href>` / `xlink:href`, `<object data>`, `<embed src>`, and `<video poster>` are inlined the same way as `src`; a missing or `https` candidate stays. `<script>` tags and `on*` event attributes are removed and are not executed.
- EPUB chapter CSS `@import` statements without media queries are expanded inline. `@import` statements with media queries (e.g., `@import url("print.css") print;`) are preserved.
- EPUB2 NCX nested navPoints become nested TOC items. A navPoint with child navPoints appears as a parent with children in the table of contents; child navPoints keep their fragment (e.g., `ch1.xhtml#section1` becomes fragment `section1`). A corrupt NCX falls back to the spine, not an empty TOC.
- FB2 external links (`http://`, `https://`, `mailto:`) stay as clickable `<a>` tags with `class="external-link"`. Internal `#id` links stay as internal anchors. Empty links are omitted.
- External links (`http://`, `https://`, `mailto:`) in EPUB and FB2 books open in the system browser when clicked. Invalid URLs are ignored.
- FB2 chapter `<image l:href="#id">` becomes an `<img>` data URI from that file's `binary`. A missing binary stays missing; an image `style` becomes `class` on that `<img>`; an empty style is omitted; an image `alt` is copied onto that `<img>`; an empty alt is omitted; an image `title` is copied onto that `<img>`; an empty title is omitted; an image `id` is copied onto that `<img>`; an empty id is omitted; a cover binary is not inserted into a chapter that does not reference it. FB2 `<emphasis>` and `<strong>` stay as `<em>` and `<strong>` in chapter HTML. `<strikethrough>` stays as `<s>`. `<sub>` and `<sup>` stay as `<sub>` and `<sup>`. `<code>` stays as `<code>`. A named `<style>` stays as `<span class>` with that name; an empty or unnamed style keeps the text only. A FictionBook stylesheet is not copied into chapter HTML. `<a l:href="#id">` stays as `<a href="#id">`; a section `id` is copied onto the chapter `<section>`. When that id belongs to another chapter, the href becomes `section-N#id`. Paragraph `id` and empty `<a id>` anchors are copied the same way. An image `id` is looked up the same way. A subtitle `id` is looked up the same way. A paragraph `style` attribute becomes `class`; an empty style is omitted. A verse `<v style>` becomes a `span class` on that line; an empty verse stays omitted. A section `<subtitle style>` becomes `class` on that `<h2>`; a section `<subtitle id>` becomes `id` on that `<h2>`; an empty id is omitted; an empty subtitle stays omitted. A poem `<subtitle style>` becomes `class` on that `<h4>`; a poem `<subtitle id>` becomes `id` on that `<h4>`; an empty id is omitted; an empty poem subtitle stays omitted. A stanza `<subtitle style>` becomes `class` on that `<h5>`; a stanza `<subtitle id>` becomes `id` on that `<h5>`; an empty stanza subtitle stays omitted. A stanza `<subtitle style>` becomes `class` on that `<h5>`; an empty stanza subtitle stays omitted. A cite or epigraph `<subtitle style>` becomes `class` on that `<h2>`; a cite or epigraph `<subtitle id>` becomes `id` on that `<h2>`; an empty id is omitted; an empty quote subtitle stays omitted. An annotation `<subtitle style>` becomes `class` on that `<h2>`; an empty annotation subtitle stays omitted. A body-level `<subtitle style>` before the first section becomes `class` on that `<h2>`; an empty body subtitle stays omitted. A body-level `<title style>` becomes `class` on that `<h1>`; an empty body title stays omitted. A section `<title style>` becomes `class` on that `<h1>`; an empty section title stays omitted. A poem `<title style>` becomes `class` on that `<h3>`; an empty poem title stays omitted. A stanza `<title style>` becomes `class` on that `<h4>`; an empty stanza title stays omitted. The first section's chapter title still comes from that section. An `https` / `mailto` href keeps the link text and is not opened. `<empty-line/>` becomes a blank paragraph; `<subtitle>` becomes `<h2>` and is searchable. A `<poem>` keeps verse lines with breaks in chapter HTML; a poem-only section still opens. An epigraph nested in a poem stays in that poem. A poem `<subtitle>` stays as `<h4>`. A poem `<text-author>` stays in that poem; a poem `<text-author style>` becomes `class` on that `<p>`; an empty poem text-author stays omitted. A cite or epigraph `<text-author style>` becomes `class` on that `<p>`; an empty quote text-author stays omitted. A poem `<date>` stays in that poem; a poem `<date style>` becomes `class` on that `<p>` (including a `value` fallback); an empty date uses its `value` attribute. A stanza `<title>` / `<subtitle>` stays as `<h4>` / `<h5>`. A section `<table>` becomes an HTML table; a table `<title>` becomes `<caption>`; a table `<title style>` becomes `class` on that `<caption>`; an empty table title stays omitted; a positive `colspan` / `rowspan` is copied onto the cell; `align` (`left` / `right` / `center`) and `valign` (`top` / `middle` / `bottom`) are copied the same way; a table cell `style` becomes `class`; an empty style is omitted; a table `style` becomes `class` on that `<table>`; an empty table style is omitted; a table row `style` becomes `class` on that `<tr>`; an empty row style is omitted; an empty table is omitted and a table-only section still opens. `<epigraph>` and `<cite>` become `<blockquote>` (paragraphs, subtitle, empty-line, text-author, poem, table, and a nested cite) and are searchable. A section `<annotation>` becomes an `<aside>` (paragraphs, subtitle, empty-line, cite, poem, and table); an empty annotation is omitted and an annotation-only section still opens.
- FB2 shelf covers follow the `title-info` coverpage image href on both Flutter import and the local Rust service. A missing coverpage, `https` href, or unmatched binary stays without a cover; a chapter binary whose id contains `cover` is not used as the cover.
- A FB2 `title-info` annotation becomes the first TOC chapter (`annotation`) using the same aside HTML as a section annotation. An empty annotation or a `src-title-info` annotation does not add a chapter; body sections still use `section-0`.
- FB2 nested sections appear under their titled parent in the TOC. An untitled wrapper section is omitted; tapping a child still opens that child's href.
- FB2 `body name="notes"` and `name="comments"` sections stay readable with the same `section-N` hrefs, and appear as separate TOC groups after the main text. An empty notes body or an unnamed second body does not add a group. A notes or comments body without `<section>` still becomes that group when the book has main chapters; a notes-only file without sections stays corrupt.
- An FB2 main `body` without `<section>` still opens: its direct blocks become `section-0` (and later bodies keep document order). A body that already has sections does not emit leftover body-level paragraphs as another chapter. An empty body or a notes-only body without sections stays corrupt.
- An epigraph or cite on an FB2 body, before its first section, is kept at the start of that body's first chapter. An empty quote is omitted. A notes/comments body epigraph is not merged into the main first chapter. A body-level image, empty-line, subtitle, poem, table, annotation, title, or paragraph in that same place is kept the same way; a missing binary stays missing. An empty table, annotation, title, or paragraph is omitted. The first section's chapter title still comes from that section.
- The reader TOC current item follows the open chapter href (and EPUB fragment). Nested FB2 books highlight the child and show the chapter count in the chrome instead of the top-level TOC length.
- Embedded EPUB fonts in chapter CSS `url()` become `data:` URIs. A missing font file keeps its path.
- Chapter CSS `@import` without a media query is replaced with that file, then `url()` is inlined. A missing or `https` import stays; a circular import does not hang.
- Reflow page turns and progress follow viewport pages reported by the Foliate host. Tests without a WebView still use character pages.
- Note quotes are painted in the Foliate chapter HTML. A missing quote is not filled from another book; bookmarks are not highlights.
- In-chapter EPUB links jump inside the current book. External `http` / `https` / `mailto` hrefs open in the system browser; a missing chapter stays on the current one.
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
