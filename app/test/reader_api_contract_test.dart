import 'dart:convert';

import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reader runtime and locator schema versions are explicit', () {
    expect(readerRuntimeApiVersion, '1.0.0');
    expect(locatorSchemaVersion, 1);
  });

  test('versioned locator JSON freezes the public field names', () {
    expect(
      locatorToJson(
        const EpubLocator(
          href: 'OEBPS/chapter.xhtml',
          cfi: '/6/4',
          progression: 0.42,
          fragment: 'note',
        ),
      ),
      {
        'version': 1,
        'kind': 'epub',
        'href': 'OEBPS/chapter.xhtml',
        'cfi': '/6/4',
        'progression': 0.42,
        'fragment': 'note',
      },
    );
    expect(locatorToJson(const PdfLocator(page: 3, x: 1.5, y: 2.5)), {
      'version': 1,
      'kind': 'pdf',
      'page': 3,
      'x': 1.5,
      'y': 2.5,
    });
    expect(locatorToJson(const ComicLocator(page: 4)), {
      'version': 1,
      'kind': 'comic',
      'page': 4,
    });
    expect(locatorToJson(const TextLocator(offset: 128)), {
      'version': 1,
      'kind': 'text',
      'offset': 128,
    });
  });

  test('all public locator kinds round-trip through locator schema v1', () {
    final locators = <Locator>[
      const EpubLocator(
        href: 'chapter.xhtml',
        cfi: '/2/4',
        progression: 0.2,
        fragment: 'fragment',
      ),
      const PdfLocator(page: 2, x: 10, y: 20),
      const ComicLocator(page: 5),
      const TextLocator(offset: 4096),
    ];

    for (final locator in locators) {
      final decoded = decodeLocatorJson(encodeLocatorJson(locator));
      expect(decoded, isNotNull);
      expect(locatorToJson(decoded!), locatorToJson(locator));
    }
  });

  test('locator schema rejects unknown versions and malformed values', () {
    expect(decodeLocatorJson('not json'), isNull);
    expect(
      locatorFromJson({'kind': 'text', 'offset': 1}),
      isNull,
      reason: 'version is required',
    );
    expect(
      locatorFromJson({'version': 2, 'kind': 'text', 'offset': 1}),
      isNull,
    );
    expect(locatorFromJson({'version': 1, 'kind': 'epub', 'href': ''}), isNull);
    expect(
      locatorFromJson({
        'version': 1,
        'kind': 'pdf',
        'page': 1,
        'x': double.nan,
      }),
      isNull,
    );
  });

  test('encoding a locator produces valid standalone JSON', () {
    final decoded = jsonDecode(encodeLocatorJson(const TextLocator(offset: 1)));
    expect(decoded, {'version': 1, 'kind': 'text', 'offset': 1});
  });
}
