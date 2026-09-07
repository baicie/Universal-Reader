import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentRange', () {
    test('carries the start and end locators verbatim', () {
      const start = EpubLocator(href: 'start.xhtml');
      const end = EpubLocator(href: 'end.xhtml');
      const range = DocumentRange(start: start, end: end);
      expect(range.start, same(start));
      expect(range.end, same(end));
    });

    test('can mix locator kinds', () {
      const range = DocumentRange(
        start: TextLocator(offset: 0),
        end: ComicLocator(page: 2),
      );
      expect(range.start, isA<TextLocator>());
      expect(range.end, isA<ComicLocator>());
    });
  });

  group('TocItem', () {
    test('defaults children to an empty list', () {
      const item = TocItem(
        title: 'Chapter 1',
        locator: EpubLocator(href: 'ch1.xhtml'),
      );
      expect(item.title, 'Chapter 1');
      expect(item.locator, isA<EpubLocator>());
      expect(item.children, isEmpty);
    });

    test('can nest a tree of children', () {
      const leaf = TocItem(
        title: 'Section 1.1',
        locator: EpubLocator(href: 'ch1.xhtml#s1'),
      );
      final parent = TocItem(
        title: 'Chapter 1',
        locator: const EpubLocator(href: 'ch1.xhtml'),
        children: const [leaf],
      );
      expect(parent.children, [leaf]);
      expect(parent.children.first.title, 'Section 1.1');
    });
  });

  group('SearchResult', () {
    test('exposes title, excerpt and locator verbatim', () {
      const result = SearchResult(
        title: 'Chapter 1',
        excerpt: 'matching paragraph',
        locator: PdfLocator(page: 12),
      );
      expect(result.title, 'Chapter 1');
      expect(result.excerpt, 'matching paragraph');
      expect(result.locator, isA<PdfLocator>());
    });
  });

  test('Sealed Locator subclasses compile and stay distinct', () {
    const locators = <Locator>[
      PdfLocator(page: 1),
      EpubLocator(href: 'a'),
      TextLocator(offset: 1),
      ComicLocator(page: 1),
    ];
    expect(locators.length, 4);
    expect(locators[0], isA<PdfLocator>());
    expect(locators[1], isA<EpubLocator>());
    expect(locators[2], isA<TextLocator>());
    expect(locators[3], isA<ComicLocator>());
  });
}
