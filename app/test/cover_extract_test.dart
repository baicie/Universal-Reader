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

  group('extractCover by format', () {
    test('cbz archive returns the first sorted image', () {
      final bytes = zipNamedFiles({
        // Inserted out of sort order so the file proves it sorts by name.
        'zzz.png': [1, 2, 3],
        'aaa.jpg': tinyPngBytes(),
        'notes.txt': 'not an image'.codeUnits,
      });
      expect(extractCover(fileName: 'book.cbz', bytes: bytes), tinyPngBytes());
    });

    test('cbr archive returns the first sorted image', () {
      final bytes = zipNamedFiles({'page.jpg': tinyPngBytes()});
      expect(extractCover(fileName: 'book.cbr', bytes: bytes), tinyPngBytes());
    });

    test('zip without any image returns null', () {
      final bytes = zipNamedFiles({'notes.txt': 'hi'.codeUnits});
      expect(extractCover(fileName: 'book.cbz', bytes: bytes), isNull);
    });

    test('zip with only macOS resource-fork entries returns null', () {
      final bytes = zipNamedFiles({
        '__macosx/cover.png': tinyPngBytes(),
        '.DS_Store': 'noise'.codeUnits,
      });
      expect(extractCover(fileName: 'book.cbz', bytes: bytes), isNull);
    });

    test('epub without cover metadata falls back to first sorted image', () {
      final bytes = zipNamedFiles({
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
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="page" href="zzz.png" media-type="image/png"/>
    <item id="early" href="aaa.jpg" media-type="image/jpeg"/>
  </manifest>
</package>
'''
                .codeUnits,
        'OEBPS/zzz.png': [1, 2, 3],
        'OEBPS/aaa.jpg': tinyPngBytes(),
        'OEBPS/ch1.xhtml': '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><p>x</p></body></html>'
            .codeUnits,
      });
      expect(extractCover(fileName: 'book.epub', bytes: bytes), tinyPngBytes());
    });

    test('epub without container.xml surfaces as null', () {
      final bytes = zipNamedFiles({
        'mimetype': 'application/epub+zip'.codeUnits,
        // No container.xml — _read throws FormatException; the catch in
        // extractCover turns that into null instead of crashing.
        'OEBPS/aaa.png': tinyPngBytes(),
      });
      expect(extractCover(fileName: 'book.epub', bytes: bytes), isNull);
    });

    test('epub with corrupt container.xml surfaces as null', () {
      final bytes = zipNamedFiles({
        'mimetype': 'application/epub+zip'.codeUnits,
        'META-INF/container.xml': 'not-xml-at-all'.codeUnits,
        'OEBPS/cover.png': tinyPngBytes(),
      });
      expect(extractCover(fileName: 'book.epub', bytes: bytes), isNull);
    });

    test('epub with cover meta id pointing to wrong id falls back', () {
      final bytes = zipNamedFiles({
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
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>t</dc:title>
    <meta name="cover" content="not-a-real-id"/>
  </metadata>
  <manifest>
    <item id="page" href="cover.png" media-type="image/png"/>
  </manifest>
</package>
'''
                .codeUnits,
        'OEBPS/cover.png': tinyPngBytes(),
      });
      expect(extractCover(fileName: 'book.epub', bytes: bytes), tinyPngBytes());
    });

    test('epub with cover meta id resolves into nested folder', () {
      final bytes = zipNamedFiles({
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
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="images/cover.png" media-type="image/png"/>
  </manifest>
</package>
'''
                .codeUnits,
        'OEBPS/images/cover.png': tinyPngBytes(),
      });
      expect(extractCover(fileName: 'book.epub', bytes: bytes), tinyPngBytes());
    });
  });

  group('looksLikeImageName', () {
    test('accepts png/jpg/jpeg/webp/gif case-insensitively', () {
      expect(looksLikeImageName('cover.png'), isTrue);
      expect(looksLikeImageName('cover.PNG'), isTrue);
      expect(looksLikeImageName('cover.jpg'), isTrue);
      expect(looksLikeImageName('cover.jpeg'), isTrue);
      expect(looksLikeImageName('cover.webp'), isTrue);
      expect(looksLikeImageName('cover.gif'), isTrue);
    });

    test('rejects non-image extensions', () {
      expect(looksLikeImageName('chapter.xhtml'), isFalse);
      expect(looksLikeImageName('mimetype'), isFalse);
      expect(looksLikeImageName('cover.pngx'), isFalse);
    });

    test('rejects dotfiles and macOS resource forks', () {
      expect(looksLikeImageName('.cover.png'), isFalse);
      expect(looksLikeImageName('__macosx/cover.png'), isFalse);
      // The contains check is case-sensitive; only the lowercase spelling is
      // filtered. This documents that intentional quirk so a future fix
      // knows it is changing behaviour.
      expect(looksLikeImageName('__MACOSX/cover.png'), isTrue);
    });

    test('normalizes backslashes before deciding', () {
      expect(looksLikeImageName(r'folder\cover.png'), isTrue);
      expect(looksLikeImageName(r'__macosx\cover.png'), isFalse);
    });
  });

  group('fb2 coverpage edge cases', () {
    test('fb2 coverpage with http url returns null (no network fetch)', () {
      final bytes = fb2CoverpageBytes(coverHref: 'http://example.com/c.png');
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
    });

    test('fb2 coverpage with https url returns null', () {
      final bytes = fb2CoverpageBytes(coverHref: 'https://example.com/c.png');
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
    });

    test('fb2 coverpage with protocol-relative url returns null', () {
      final bytes = fb2CoverpageBytes(coverHref: '//cdn.example.com/c.png');
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
    });

    test('fb2 coverpage with empty href returns null', () {
      final bytes = fb2CoverpageBytes(coverHref: '#');
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
    });

    test('fb2 coverpage matches binary id case-insensitively', () {
      final bytes = fb2CoverpageBytes(
        coverHref: '#Cover.PNG',
        binaryId: 'cover.png',
      );
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), tinyPngBytes());
    });

    test('fb2 coverpage with empty binary content returns null', () {
      final bytes = fb2CoverpageBytes(coverHref: '#cover.png', imageBytes: []);
      // Empty bytes → empty decoded → null.
      expect(extractCover(fileName: 'book.fb2', bytes: bytes), isNull);
    });
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
