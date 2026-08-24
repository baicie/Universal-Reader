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
- Settings screen with light/dark/system theme selection

## Architecture follow-up

The renderer contracts intentionally isolate third-party implementations. The next production layers can add `FoliateEngineAdapter`, `PdfRenderer`, and `ComicRenderer` without coupling those packages to Library or Reader UI. Rust Core and SQLite/FTS5 should be connected behind repository interfaces after the Flutter application contracts stabilize.
