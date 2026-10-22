# Expo phone device smoke

This checklist validates the Expo / React Native client in `mobile/` on Android or iOS. It is separate from [Flutter physical-device smoke](physical-device-smoke.md). Node tests, Expo Web checks, and Metro exports are useful prerequisites; none records a phone-device pass.

## Build and record

Use an actual installed build for the intended commit. The current Release workflow publishes EAS `preview` Android APKs; iOS testing requires a separately prepared development or signed build on suitable hardware.

For each run record:

| Field | Value |
| --- | --- |
| Date / tester | Pending |
| Platform / device / OS | Pending |
| Source commit / tag | Pending |
| App version / native build number | Pending |
| Build URL / APK or IPA SHA-256 | Pending |
| Fresh install or upgrade | Pending |

Copy the sample files to the device and import them through the system file picker. Use both the repository's [compatibility corpus](../test-books/README.md) and representative real books with decodable page images. Some tiny comic fixtures contain only an image signature and cannot demonstrate that a bitmap renders correctly.

## Required checks

Record each case as `PASS`, `FAIL`, `UNAVAILABLE`, or `NOT RUN`, with the observed result and logs/screenshots where helpful. The template below deliberately starts at `NOT RUN`.

| Case | Expected result | Android | iOS |
| --- | --- | --- | --- |
| Launch and import | App launches; file picker imports the chosen book; cancellation preserves the shelf | NOT RUN | NOT RUN |
| TXT / Markdown / HTML | Own text and chapters display; CJK / BOM samples decode; empty and corrupt files show appropriate errors | NOT RUN | NOT RUN |
| EPUB / FB2 | Own chapters, images, TOC and cover display; chapter pagination and fragment navigation stay in the same book | NOT RUN | NOT RUN |
| PDF | Actual pages and text layer render; page navigation, zoom, search, selection and notes use the current page | NOT RUN | NOT RUN |
| RTF / DOCX / ODT | Sample text and chapter boundaries match the files | NOT RUN | NOT RUN |
| MOBI / AZW3 | Supported embedded EPUB or readable-text fallback opens; format limitations are recorded | NOT RUN | NOT RUN |
| CBZ / CBT | Actual images render in order; single / double / vertical / RTL modes preserve position | NOT RUN | NOT RUN |
| CBR / CB7 | With WebAssembly, RAR / 7z decode and actual images render; without it, the app reports unsupported rather than corrupt | NOT RUN | NOT RUN |
| DjVu / DJV | With WebAssembly, pages and cover render with correct count; without it, the app reports unsupported rather than corrupt | NOT RUN | NOT RUN |
| CHM | Shared TypeScript parser opens the book's own HTML chapters; native file import and chapter navigation work | NOT RUN | NOT RUN |
| Persistence | Reopen / force-close / relaunch preserves shelf, progress, cover, settings, bookmarks and notes | NOT RUN | NOT RUN |
| Upgrade | Installing the new build over the previous installed build preserves the existing shelf and progress | NOT RUN | NOT RUN |
| WebDAV / S3 | Import and upload own books; same-name remote files remain intact; metadata merge preserves the newer position | NOT RUN | NOT RUN |
| Reading assistant | With test configuration, only the chosen book's text is sent; answer persists; navigation waits for confirmation; failure leaves position intact | NOT RUN | NOT RUN |
| Offline / errors | Local books reopen offline; cancelled operations, network failures and corrupt files preserve other books | NOT RUN | NOT RUN |

## Result

Current checked-in status: **no Expo Android or iOS physical-device pass is recorded by this document**. Fill in run details and actual outcomes before declaring device validation complete. A decoder or platform marked unavailable remains a release limitation even when all other checks pass.
