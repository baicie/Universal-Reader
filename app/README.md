# Universal Reader App

Flutter implementation of the Universal Reader design in `../index.md`.

## Run

Flutter SDK is installed at `D:\install\flutter`.

```powershell
$env:Path = 'D:\install\flutter\bin;' + $env:Path
flutter pub get
flutter run -d chrome
```

## Verify

```powershell
flutter analyze
flutter test
flutter build web --release
```

## Implemented foundation

- Flutter shell with Material 3 theme and responsive desktop/mobile layout
- Riverpod state boundary for Library and reader theme
- go_router routes for Library, Reader, and Settings
- Reader Runtime contracts: `ReaderDocument`, `DocumentRenderer`, `DocumentAdapter`, `Locator`
- EPUB/PDF/MOBI/AZW3/FB2/TXT/Markdown/HTML/CBZ/CBR first-pass format detector
- Local file import through `file_picker`
- Library search, type filters, sorting, grid/list view, reading progress
- Reader screen with TOC, progress slider, content theme surface, and mobile chrome behavior
- TXT, Markdown, and HTML files open as real text; other formats show a not-yet-readable state
- Settings screen with light/dark/system theme and Chinese/English/system language (Chinese is the default and fallback)

## Rust backend integration

The local Rust service is in `../rust/crates/reader-server`. It currently supplies health reporting, first-pass format detection, on-disk library storage, and optional hosting of `flutter build web --release` over HTTP. When `/health` is reachable, the Flutter app uses `HttpLibraryRepository` against that store; otherwise it falls back to SharedPreferences. See the repository README for the combined web + server release layout.

## Architecture follow-up

The renderer contracts intentionally isolate third-party implementations. The next production layers can add `FoliateEngineAdapter`, `PdfRenderer`, and `ComicRenderer` without coupling those packages to Library or Reader UI. Rust Core and SQLite/FTS5 should be connected behind repository interfaces after the Flutter application contracts stabilize.
