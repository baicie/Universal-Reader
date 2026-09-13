# DOCX Reader

Universal Reader treats DOCX as a reflow document, not as an Office editor.
The target is readable structure and text, not pixel-perfect Word layout.

## Pipeline

```text
DOCX ZIP
  -> word/document.xml
  -> DocxReaderDocument
  -> HtmlChapteredDocument
  -> Foliate renderer
```

The parser reads `docProps/core.xml` for title and author, then walks the body
in document order. Heading 1 and Heading 2 paragraphs start reader chapters.
Other paragraphs remain in the current chapter.

## Supported Structure

- Paragraphs and line breaks
- Heading 1-6 and Word outline levels
- Bold, italic, underline, strike, superscript, and subscript runs
- External hyperlinks resolved through `document.xml.rels`
- Basic tables
- List paragraphs as readable list items

DOCX is detected from the ZIP member `word/document.xml`, so a renamed `.docx`
still imports correctly. A ZIP without that member is not treated as DOCX.

## Current Limits

- Embedded images, headers, footers, footnotes, comments, and tracked changes
  are not rendered yet.
- Complex page layout, floating objects, text boxes, and exact styling are out
  of scope.
- Legacy binary `.doc` files are not supported.
