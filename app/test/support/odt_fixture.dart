import 'dart:convert';

import 'epub_fixture.dart';

List<int> minimalOdtBytes({
  String title = 'ODT Compatibility Book',
  String author = 'Libre Writer',
  String firstTitle = 'Chapter One',
  String secondTitle = 'Chapter Two',
}) {
  return zipNamedFiles(
    {
      'mimetype': utf8.encode('application/vnd.oasis.opendocument.text'),
      'content.xml': utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  office:version="1.3">
  <office:automatic-styles>
    <style:style style:name="T1" style:family="text">
      <style:text-properties fo:font-weight="bold"/>
    </style:style>
    <style:style style:name="T2" style:family="text">
      <style:text-properties fo:font-style="italic"/>
    </style:style>
    <style:style style:name="TStrong" style:family="text" style:parent-style-name="T1">
      <style:text-properties style:text-underline-style="solid"/>
    </style:style>
  </office:automatic-styles>
  <office:body>
    <office:text>
      <text:h text:outline-level="1" text:style-name="Heading_20_1">$firstTitle</text:h>
      <text:p>Hello <text:span text:style-name="T1">bold</text:span> and <text:span text:style-name="T2">italic</text:span> and <text:span text:style-name="TStrong">strong underline</text:span>.</text:p>
      <text:list>
        <text:list-item><text:p>First item</text:p></text:list-item>
        <text:list-item><text:p>Second item</text:p></text:list-item>
      </text:list>
      <table:table>
        <table:table-row>
          <table:table-cell><text:p>Key</text:p></table:table-cell>
          <table:table-cell><text:p>Value</text:p></table:table-cell>
        </table:table-row>
        <table:table-row>
          <table:table-cell><text:p>Format</text:p></table:table-cell>
          <table:table-cell><text:p>ODT</text:p></table:table-cell>
        </table:table-row>
      </table:table>
      <text:p><text:a xlink:href="https://example.com">External link</text:a></text:p>
      <text:h text:outline-level="2" text:style-name="Heading_20_2">$secondTitle</text:h>
      <text:p>Second chapter body.</text:p>
    </office:text>
  </office:body>
</office:document-content>'''),
      'meta.xml': utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">
  <office:meta>
    <dc:title>$title</dc:title>
    <meta:initial-creator>$author</meta:initial-creator>
    <dc:creator>$author</dc:creator>
  </office:meta>
</office:document-meta>'''),
    },
    uncompressed: const {'mimetype'},
  );
}
