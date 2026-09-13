# DjVu Reader

DjVu is supported through the optional local Rust service. The service uses
the MIT-licensed pure-Rust `djvu-rs` renderer to decode pages, renders each
page to a PNG at 150 DPI, and packages the pages as a CBZ comic archive.
Flutter reads the converted archive through the existing comic renderer.

## Pipeline

```text
DjVu
  -> Rust service
  -> djvu-rs page rendering
  -> PNG page images
  -> CBZ archive
  -> Flutter comic reader
```

## Platform Status

- Desktop, server, and Web sessions connected to the local Rust service can
  import and read DjVu files.
- Flutter-only mobile sessions can detect DjVu but do not yet render it
  in-process. Embedding a cross-platform decoder is a v1.0 platform task.
- The original `.djvu` file remains the logical library item; the service
  serves its converted CBZ representation when the book is opened.

## Current Limits

- Rendering is fixed at 150 DPI for the imported CBZ.
- Metadata, annotations, and hyperlink regions are not converted in this
  first pass.
- Text-layer search is not preserved; page navigation uses the converted
  comic pages.
