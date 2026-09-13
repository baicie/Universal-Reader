# CBT Reader

CBT is a TAR archive of comic images. Universal Reader treats it as another
comic container, so page navigation, single-page, double-page, vertical, and
right-to-left layouts reuse the existing comic renderer.

## Pipeline

```text
CBT TAR
  -> TarDecoder
  -> ordered image entries
  -> ComicReaderDocument
  -> comic renderer
```

Format detection validates the TAR header and checks for image entries, so a
renamed `.cbt` still imports correctly. Files without images are not accepted
as comics.

## Supported Behavior

- Case-insensitive image-name ordering
- Nested directories and backslash paths
- PNG, JPEG, WebP, and GIF entries
- First-image cover extraction
- The same page locators, progress, search-by-page-name, and TOC behavior used
  by CBZ and CBR

## Current Limits

- Encrypted or compressed PAX extensions outside standard TAR support follow
  the capabilities of the `archive` package.
- Metadata inside TAR entries is not turned into book metadata.
