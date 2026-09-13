# CHM Reader

CHM is supported through the optional local Rust service. The service uses the
MIT-licensed pure-Rust `libchm` decoder to unpack ITSF/ITSP and LZX-compressed
entries, then converts the help archive into an EPUB reflow package. Flutter
reads the converted package through the existing EPUB renderer.

## Pipeline

```text
CHM
  -> Rust service
  -> libchm extraction
  -> generated EPUB ZIP
  -> Flutter EPUB reader
```

The generated package contains the CHM HTML pages, linked assets, a navigation
document, and an OPF spine sorted with `index` and `default` pages first.

## Platform Status

- Desktop, server, and Web sessions connected to the local Rust service can
  import and read CHM files.
- Flutter-only mobile sessions can detect CHM but do not yet decode it
  in-process. Embedding a cross-platform native decoder is a separate v1.0
  platform task.
- The original `.chm` file remains the logical library item; the Rust service
  serves its converted EPUB representation when the book is opened.

## Current Limits

- CHM-specific navigation controls and context IDs are not preserved.
- Only ordinary file entries are converted. Internal metadata and index
  streams are not exposed as reader content.
- Malformed or unsupported LZX entries are rejected rather than partially
  rendered.
