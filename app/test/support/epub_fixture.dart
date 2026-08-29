import 'dart:convert';

import 'package:archive/archive.dart';

import 'image_fixture.dart';

List<int> minimalEpubBytes({
  String title = 'Fixture Book',
  String author = 'Fixture Author',
  String firstTitle = '第一章',
  String firstBody = 'hello from epub',
  String secondTitle = '第二章',
  String secondBody = 'second chapter text',
  String firstHead = '',
  String firstMarkup = '',
  Map<String, List<int>> extraFiles = const {},
}) {
  final files = <String, List<int>>{
    'mimetype': utf8.encode('application/epub+zip'),
    'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
    'OEBPS/content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:language>zh</dc:language>
    <dc:identifier id="bookid">urn:uuid:fixture</dc:identifier>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
'''),
    'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="ch1.xhtml">$firstTitle</a></li>
        <li><a href="ch2.xhtml">$secondTitle</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
    'OEBPS/ch1.xhtml': utf8.encode(
      '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">${firstHead.isEmpty ? '' : '<head>$firstHead</head>'}<body><h1>$firstTitle</h1><p>$firstBody</p>$firstMarkup</body></html>',
    ),
    'OEBPS/ch2.xhtml': utf8.encode(
      '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><h1>$secondTitle</h1><p>$secondBody</p></body></html>',
    ),
    ...extraFiles,
  };
  return zipNamedFiles(files, uncompressed: const {'mimetype'});
}

List<int> illustratedEpubBytes({
  String firstBody = 'hello from epub',
  bool includeImage = true,
}) {
  return minimalEpubBytes(
    firstBody: firstBody,
    firstHead: '<link rel="stylesheet" href="styles.css"/>',
    firstMarkup: '<p class="caption">spot caption</p><img src="images/spot.png" alt="spot"/>',
    extraFiles: {
      'OEBPS/styles.css': utf8.encode('.caption { font-style: italic; }'),
      if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes(),
    },
  );
}

List<int> zipNamedFiles(
  Map<String, List<int>> files, {
  Set<String> uncompressed = const {},
}) {
  final archive = Archive();
  files.forEach((name, bytes) {
    final file = ArchiveFile(name, bytes.length, bytes);
    if (uncompressed.contains(name)) {
      file.compression = CompressionType.none;
    }
    archive.add(file);
  });
  return ZipEncoder().encode(archive);
}
