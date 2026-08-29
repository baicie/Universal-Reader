import 'package:app/core/cover_extract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  test('pulls the cover image out of an epub', () {
    final bytes = zipNamedFiles({..._minimalCoverEpub()});
    final cover = extractCover(fileName: 'book.epub', bytes: bytes);
    expect(cover, tinyPngBytes());
  });

  test('missing cover stays missing', () {
    expect(extractCover(fileName: 'notes.txt', bytes: 'hi'.codeUnits), isNull);
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
