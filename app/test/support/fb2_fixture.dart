import 'dart:convert';

/// Returns the bytes of a minimal FictionBook 2 document.
///
/// Chapters are written as `<section>` blocks inside `<body>`. Each section
/// gets a `<title>` (used as chapter title) followed by `<p>` paragraphs.
List<int> minimalFb2Bytes({
  String title = 'FB2 Book',
  String authorFirst = 'Ann',
  String authorLast = 'Author',
  List<String> chapterTitles = const ['第一章', '第二章'],
  List<String> chapterBodies = const [
    'first chapter text here',
    'second chapter text here',
  ],
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );

  // description / title-info
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  if (authorFirst.isNotEmpty || authorLast.isNotEmpty) {
    buffer.writeln('    <author>');
    if (authorFirst.isNotEmpty) {
      buffer.writeln('      <first-name>${_xml(authorFirst)}</first-name>');
    }
    if (authorLast.isNotEmpty) {
      buffer.writeln('      <last-name>${_xml(authorLast)}</last-name>');
    }
    buffer.writeln('    </author>');
  }
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');

  // body
  buffer.writeln('<body>');
  for (var i = 0; i < chapterTitles.length; i++) {
    buffer.writeln('  <section>');
    buffer.writeln('    <title>${_xml(chapterTitles[i])}</title>');
    for (final para in (chapterBodies.length > i ? chapterBodies[i] : '').split('\n')) {
      if (para.isNotEmpty) {
        buffer.writeln('    <p>${_xml(para)}</p>');
      }
    }
    buffer.writeln('  </section>');
  }
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');

  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes with an annotation / blurb in description.
List<int> fb2WithAnnotationBytes({
  String title = 'Book With Notes',
  String annotation = 'This is a short annotation blurb.',
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('    <annotation>');
  buffer.writeln('      <p>${_xml(annotation)}</p>');
  buffer.writeln('    </annotation>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  buffer.writeln('  <section>');
  buffer.writeln('    <p>main content</p>');
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes whose main body has [bodyLead] as the first children
/// (epigraph / cite / subtitle / empty-line / poem / table / annotation /
/// title / p) followed by a single chapter section.
///
/// Used to test that block-level FB2 elements like `<epigraph>`, `<cite>`,
/// `<subtitle>`, and `<empty-line/>` are rendered into the first chapter's
/// text and html.
List<int> fb2WithBodyLeadBytes({
  String title = 'Lead Body Book',
  String bodyLead = '',
  String chapterTitle = 'Chapter 1',
  List<String> chapterParagraphs = const ['main paragraph'],
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  if (bodyLead.isNotEmpty) {
    for (final line in bodyLead.split('\n')) {
      buffer.writeln('  $line');
    }
  }
  buffer.writeln('  <section>');
  buffer.writeln('    <title>${_xml(chapterTitle)}</title>');
  for (final para in chapterParagraphs) {
    buffer.writeln('    <p>${_xml(para)}</p>');
  }
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes with a single section made of [blocks] (raw XML
/// fragments). Used to embed constructs like `<poem><stanza>…</stanza></poem>`
/// that the simpler [fb2WithBodyLeadBytes] cannot express.
List<int> fb2WithChapterBlocksBytes(
  List<String> blocks, {
  String title = 'Blocks Book',
  String chapterTitle = 'Chapter 1',
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  buffer.writeln('  <section>');
  buffer.writeln('    <title>${_xml(chapterTitle)}</title>');
  for (final block in blocks) {
    for (final line in block.split('\n')) {
      buffer.writeln('    $line');
    }
  }
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes containing an inline-rich single paragraph. Use [extra]
/// to embed custom XML fragments like `<a href="#…">` or `<image href="…" />`
/// inside the paragraph. Used to test inline element rendering.
List<int> fb2WithInlineParagraphBytes({
  String title = 'Inline Book',
  String chapterTitle = 'Chapter 1',
  String textBefore = 'before ',
  String textAfter = ' after',
  String extra = '',
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  buffer.writeln('  <section>');
  buffer.writeln('    <title>${_xml(chapterTitle)}</title>');
  buffer.writeln('    <p>${_xml(textBefore)}$extra${_xml(textAfter)}</p>');
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes containing one binary image asset (`id="cover.png"`)
/// referenced by `<image l:href="#cover.png" />` from inside the chapter
/// paragraph. The image is a 1×1 transparent PNG.
List<int> fb2WithInlineImageBytes({
  String title = 'Inline Image Book',
  String chapterTitle = 'Chapter 1',
}) {
  // 1×1 transparent PNG, base64-encoded.
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"'
    ' xmlns:l="http://www.w3.org/1999/xlink">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<binary id="cover.png" content-type="image/png">'
      '$pngBase64</binary>');
  buffer.writeln('<body>');
  buffer.writeln('  <section>');
  buffer.writeln('    <title>${_xml(chapterTitle)}</title>');
  buffer.writeln('    <p><image l:href="#cover.png"/></p>');
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes with two body sections: the first one contains a
/// paragraph with `id="anchor1"` and a paragraph with an `<a l:href="#anchor1">`
/// inside another paragraph. The first chapter's html should have its `#`
/// href rewritten to point at the second chapter and re-anchor.
List<int> fb2WithCrossReferenceBytes({
  String title = 'Cross Ref Book',
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"'
    ' xmlns:l="http://www.w3.org/1999/xlink">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  buffer.writeln('  <section>');
  buffer.writeln('    <title>Chapter A</title>');
  buffer.writeln('    <p id="anchor1">target paragraph</p>');
  buffer.writeln('    <p>link below goes to '
      '<a l:href="#anchor1">the anchor</a>.</p>');
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes with a body containing two top-level sections
/// ("Part I" and "Part II"), each with a child section ("Chapter One" /
/// "Chapter Two"). Used by widget tests that navigate a nested TOC.
List<int> fb2NestedSectionBytes({
  String title = 'FB2 Book',
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>${_xml(title)}</book-title>');
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  // Part I — each part is its own navigable chapter (not a container) so the
  // parser emits two chapters and the reader shows "2 / 2".
  buffer.writeln('  <section>');
  buffer.writeln('    <title>Part I</title>');
  buffer.writeln('    <p>Part one content</p>');
  buffer.writeln('  </section>');
  buffer.writeln('  <section>');
  buffer.writeln('    <title>Part II</title>');
  buffer.writeln('    <p>Part two content</p>');
  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

/// Returns FB2 bytes that point to an embedded binary as the cover.
///
/// [coverHref] is the value of the `<image href="…">` attribute on the
/// `<coverpage>` element. When null the coverpage element is omitted.
/// [binaryId] is the id of the `<binary>` element carrying the cover image.
List<int> fb2CoverpageBytes({
  String? coverHref = '#cover.png',
  String binaryId = 'cover.png',
  List<int>? imageBytes,
  bool corruptBinary = false,
}) {
  final png = imageBytes ?? _defaultPng();
  final encoded = corruptBinary
      ? '!!!not-base64!!!'
      : base64.encode(png);
  final buffer = StringBuffer();
  buffer.writeln(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">',
  );
  buffer.writeln('<description>');
  buffer.writeln('  <title-info>');
  buffer.writeln('    <book-title>Cover Book</book-title>');
  if (coverHref != null) {
    buffer.writeln('    <coverpage>');
    buffer.writeln('      <image l:href="${_xml(coverHref)}"/>');
    buffer.writeln('    </coverpage>');
  }
  buffer.writeln('  </title-info>');
  buffer.writeln('</description>');
  buffer.writeln('<body>');
  buffer.writeln('  <section><p>main content</p></section>');
  buffer.writeln('</body>');
  buffer.writeln('<binary id="${_xml(binaryId)}" content-type="image/png">');
  buffer.writeln(encoded);
  buffer.writeln('</binary>');
  buffer.writeln('</FictionBook>');
  return utf8.encode(buffer.toString());
}

String _xml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

// Minimal 1x1 PNG so FB2 cover fixtures can ship an embedded image without
// pulling in image_fixture.dart (which is only needed when a test reads the
// bytes back).
List<int> _defaultPng() => [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
  0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
];
