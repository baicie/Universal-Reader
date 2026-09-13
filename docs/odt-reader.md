# ODT Reader

Universal Reader reads OpenDocument Text through the shared office reflow
pipeline. The goal is readable structure, not exact LibreOffice layout.

## Pipeline

```text
ODT ZIP
  -> mimetype
  -> content.xml
  -> OdtReaderDocument
  -> ReflowReaderDocument
  -> Foliate renderer
```

The parser validates `application/vnd.oasis.opendocument.text`, reads title
and author from `meta.xml`, and walks `office:text` in document order.
Heading 1 and Heading 2 start chapters.

## Supported Structure

- Paragraphs, tabs, line breaks, and repeated spaces
- Heading outline levels and Heading style names
- Named and automatic text styles, including parent style inheritance
- Bold, italic, underline, strike, superscript, and subscript
- External hyperlinks
- Lists and basic tables

ODT is detected from its package `mimetype`, so a renamed `.odt` still imports
correctly. A plain ZIP without that exact mimetype is not treated as ODT.

## Current Limits

- Embedded images, frames, headers, footers, footnotes, comments, and tracked
  changes are not rendered yet.
- Page layout, columns, text boxes, and exact spacing are out of scope.
