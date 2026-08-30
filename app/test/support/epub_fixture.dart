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

List<int> svgImageEpubBytes({
  bool includeImage = true,
  bool xlink = false,
  bool remote = false,
}) {
  final attr = xlink ? 'xlink:href' : 'href';
  final url = remote ? 'https://example.com/spot.png' : 'images/spot.png';
  final ns = xlink ? ' xmlns:xlink="http://www.w3.org/1999/xlink"' : '';
  return minimalEpubBytes(
    firstMarkup: '<svg$ns><image $attr="$url" width="1" height="1"/></svg>',
    extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
  );
}

List<int> srcsetEpubBytes({bool includeImage = true, bool remote = false}) {
  if (remote) {
    return minimalEpubBytes(
      firstMarkup: '<img src="images/spot.png" srcset="https://example.com/spot.png 1x" alt="spot"/>',
      extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
    );
  }
  return minimalEpubBytes(
    firstMarkup: '<picture><source srcset="images/spot.png 1x, images/spot.png 2x"/><img src="images/spot.png" alt="spot"/></picture>',
    extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
  );
}

List<int> objectImageEpubBytes({
  bool includeImage = true,
  bool remote = false,
}) {
  final url = remote ? 'https://example.invalid/spot.png' : 'images/spot.png';
  return minimalEpubBytes(
    firstMarkup: '<object data="$url" type="image/png">spot</object>',
    extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
  );
}

List<int> embedImageEpubBytes({bool includeImage = true, bool remote = false}) {
  final url = remote ? 'https://example.invalid/spot.png' : 'images/spot.png';
  return minimalEpubBytes(
    firstMarkup: '<embed src="$url" type="image/png"/>',
    extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
  );
}

List<int> videoPosterEpubBytes({
  bool includeImage = true,
  bool remote = false,
}) {
  final url = remote ? 'https://example.invalid/spot.png' : 'images/spot.png';
  return minimalEpubBytes(
    firstMarkup: '<video poster="$url" src="clip.mp4"></video>',
    extraFiles: {if (includeImage) 'OEBPS/images/spot.png': tinyPngBytes()},
  );
}

List<int> nestedNavEpubBytes() {
  return minimalEpubBytes(
    firstMarkup: '<p id="note">footnote target</p>',
    extraFiles: {
      'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li>
          <a href="ch1.xhtml">第一章</a>
          <ol>
            <li><a href="ch1.xhtml#note">注释</a></li>
          </ol>
        </li>
        <li><a href="ch2.xhtml">第二章</a></li>
        <li><a href="ghost.xhtml">幽灵章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
    },
  );
}

List<int> tinyTtfBytes() => [0x00, 0x01, 0x00, 0x00];

List<int> fontedEpubBytes({bool includeFont = true}) {
  return minimalEpubBytes(
    firstHead: '<link rel="stylesheet" href="styles.css"/>',
    extraFiles: {
      'OEBPS/styles.css': utf8.encode(
        '@font-face { font-family: Body; src: url(fonts/body.ttf); } '
        'body { font-family: Body, serif; }',
      ),
      if (includeFont) 'OEBPS/fonts/body.ttf': tinyTtfBytes(),
    },
  );
}

List<int> importedCssEpubBytes({
  bool includeImported = true,
  bool circular = false,
  bool remoteImport = false,
}) {
  if (circular) {
    return minimalEpubBytes(
      firstHead: '<link rel="stylesheet" href="styles.css"/>',
      extraFiles: {
        'OEBPS/styles.css': utf8.encode(
          '@import url(styles.css); p { color: red; }',
        ),
      },
    );
  }
  if (remoteImport) {
    return minimalEpubBytes(
      firstHead: '<link rel="stylesheet" href="styles.css"/>',
      extraFiles: {
        'OEBPS/styles.css': utf8.encode(
          '@import url(https://example.com/theme.css); '
          'body { font-family: serif; }',
        ),
      },
    );
  }
  return minimalEpubBytes(
    firstHead: '<link rel="stylesheet" href="styles.css"/>',
    extraFiles: {
      'OEBPS/styles.css': utf8.encode(
        '@import url(theme.css); body { font-family: Body, serif; }',
      ),
      if (includeImported)
        'OEBPS/theme.css': utf8.encode(
          '@font-face { font-family: Body; src: url(fonts/body.ttf); }',
        ),
      if (includeImported) 'OEBPS/fonts/body.ttf': tinyTtfBytes(),
    },
  );
}

List<int> nestedImportedCssEpubBytes() {
  return minimalEpubBytes(
    firstHead: '<link rel="stylesheet" href="styles.css"/>',
    extraFiles: {
      'OEBPS/styles.css': utf8.encode('@import url(css/theme.css);'),
      'OEBPS/css/theme.css': utf8.encode(
        '@font-face { font-family: Body; src: url(../fonts/body.ttf); }',
      ),
      'OEBPS/fonts/body.ttf': tinyTtfBytes(),
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
