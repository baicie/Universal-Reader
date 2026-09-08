import 'dart:convert';

/// Returns the bytes of a minimal FictionBook 2 document.
///
/// Chapters are written as <section> blocks inside <body>. Each section
/// gets a <title> (used as chapter title) followed by <p> paragraphs.
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
