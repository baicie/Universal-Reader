import 'dart:convert';

import 'epub_fixture.dart';

List<int> minimalDocxBytes({
  String title = 'DOCX Compatibility Book',
  String author = 'Ada Reader',
  String firstTitle = 'Chapter One',
  String secondTitle = 'Chapter Two',
}) {
  return zipNamedFiles({
    '[Content_Types].xml': utf8.encode('''<?xml version="1.0"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>'''),
    '_rels/.rels': utf8.encode('''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>'''),
    'docProps/core.xml': utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>$title</dc:title>
  <dc:creator>$author</dc:creator>
</cp:coreProperties>'''),
    'word/_rels/document.xml.rels': utf8.encode('''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdLink" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/>
</Relationships>'''),
    'word/document.xml': utf8.encode(
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t>$title</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>$firstTitle</w:t></w:r></w:p>
    <w:p><w:r><w:t>Hello </w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r><w:r><w:t> and </w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>italic</w:t></w:r><w:r><w:t> text.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>First item</w:t></w:r></w:p>
    <w:tbl>
      <w:tr><w:tc><w:p><w:r><w:t>Key</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc></w:tr>
      <w:tr><w:tc><w:p><w:r><w:t>Format</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>DOCX</w:t></w:r></w:p></w:tc></w:tr>
    </w:tbl>
    <w:p><w:hyperlink r:id="rIdLink"><w:r><w:rPr><w:u w:val="single"/></w:rPr><w:t>External link</w:t></w:r></w:hyperlink></w:p>
    <w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>$secondTitle</w:t></w:r></w:p>
    <w:p><w:r><w:t>Second chapter body.</w:t></w:r></w:p>
  </w:body>
</w:document>''',
    ),
  });
}
