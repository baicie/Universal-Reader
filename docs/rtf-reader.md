# RTF Reader

Universal Reader treats RTF as a reflow document. The first implementation
focuses on readable text and common document structure, not full WordPad or
Microsoft Word layout fidelity.

## Pipeline

```text
RTF bytes
  -> control-word scanner
  -> ReflowBlock[]
  -> ReflowReaderDocument
  -> Foliate renderer
```

The parser recognizes the `{\rtf` signature from content. It follows RTF
groups and destinations, ignores metadata and object groups that are not body
text, and decodes plain bytes or `\'hh` escapes using the declared ANSI code
page.

## Supported Structure

- Paragraphs, tabs, line breaks, and escaped braces/backslashes
- `\outlinelevelN` and `\sN` heading heuristics
- Bold, italic, underline, strike, superscript, and subscript
- Unicode `\uN` escapes
- Common symbol controls such as bullets and quotes
- Basic `\trowd` / `\cell` / `\row` tables
- `\title`, `\author`, and `\operator` metadata

## Current Limits

- Images, embedded objects, fields, comments, tracked changes, headers, and
  footers are not rendered.
- Complex list numbering, stylesheet inheritance, and exact paragraph layout
  are out of scope.
- Direct-formatting behavior may differ from Word for deeply nested groups.
