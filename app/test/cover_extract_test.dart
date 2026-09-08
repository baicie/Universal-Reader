import 'dart:convert';

import 'package:app/core/cover_extract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/fb2_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  test('pulls the cover image out of an epub', () {
    final bytes = zipNamedFiles({..._minimalCoverEpub()});
    final cover = extractCover(fileName: 'book.epub', bytes: bytes);
    expect(cover, tinyPngBytes());
  });

  test('pulls the cover image from an fb2 coverpage', () {
    final cover = extractCover(
      fileName: 'book.fb2',
      bytes: fb2CoverpageBytes(),
    );
    expect(cover, tinyPngBytes());
  });

  test('an fb2 coverpage with a missing binary stays without a cover', () {
    expect(
      extractCover(
        fileName: 'book.fb2',
        bytes: fb2CoverpageBytes(
          coverHref: '#missing.png',
          binaryId: 'cover.png',
        ),
      ),
      isNull,
    );
  });

  test('an fb2 binary named cover is not a cover without coverpage', () {
    expect(
      extractCover(
        fileName: 'book.fb2',
        bytes: fb2CoverpageBytes(coverHref: null, binaryId: 'cover.png'),
      ),
      isNull,
    );
  });

  test('missing cover stays missing', () {
    expect(extractCover(fileName: 'notes.txt', bytes: 'hi'.codeUnits), isNull);
  });

  test('corrupt fb2 cover binary surfaces as null without throwing', () {
    // The file points to a coverpage whose embedded binary is not valid
    // base64, so the parser must hit its catch branch and return null
    // instead of crashing or leaking the error to the caller.
    final bytes = utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>FB2 Book</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
      <coverpage><image l:href="#spot.png"/></coverpage>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>hello from fb2</p>
    </section>
  </body>
  <binary id="spot.png" content-type="image/png">!!!not-base64!!!</binary>
</FictionBook>
''');
    expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
  });
}

Map<String, List<int>> _minimalCoverEpub() {
  return {
    'mimetype': 'application/epub+zip'.codeUnits,
    'META-INF/container.xml':
        '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''
            .codeUnits,
    'OEBPS/content.opf':
        '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Covered</dc:title>
    <dc:identifier id="bookid">urn:uuid:cover</dc:identifier>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="cover.png" media-type="image/png" properties="cover-image"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>
'''
            .codeUnits,
    'OEBPS/cover.png': tinyPngBytes(),
    'OEBPS/ch1.xhtml': '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><p>hi</p></body></html>'
        .codeUnits,
  };
}
