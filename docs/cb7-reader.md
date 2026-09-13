# CB7 Reader

CB7 is a 7z archive of comic images. Universal Reader reads it through the
same comic pipeline as CBZ, CBR, and CBT.

## Pipeline

```text
CB7
  -> SevenZFormat
  -> ordered image pages
  -> ComicReaderDocument
  -> comic renderer
```

The format is detected from the `37 7A BC AF 27 1C` signature. Page entries
are decoded through the pure-Dart 7z reader with CRC verification.

## Supported Behavior

- LZMA/LZMA2, Copy, and Deflate folders
- Solid archive blocks
- Delta and BCJ x86 filter chains
- PNG, JPEG, WebP, and GIF page entries
- Case-insensitive page-name ordering
- The shared page locators, progress, page-name search, and comic layouts

## Current Limits

- Encrypted archives need a password and are not imported by the current
  comic path.
- BCJ2, PPMd, bzip2, and multi-volume archives are not decoded.
- CB7 covers are not extracted during import because 7z parsing is async.
