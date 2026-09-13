import 'package:app/core/epub_document.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'epub-search',
    title: 'fixture book',
    author: '',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  );

  EpubReaderDocument makeDocument({
    String firstBody = 'hello from epub',
    String secondBody = 'second chapter text',
    String firstTitle = 'alpha',
    String secondTitle = 'beta',
  }) {
    return EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstBody: firstBody,
        secondBody: secondBody,
        firstTitle: firstTitle,
        secondTitle: secondTitle,
      ),
    );
  }

  test('empty query returns no hits instead of inventing results', () async {
    final document = makeDocument();
    expect(await document.search(''), isEmpty);
    expect(await document.search('   '), isEmpty);
  });

  test(
    'a missing term returns no hits and does not fall back to another book',
    () async {
      final document = makeDocument(
        firstBody: 'apples and oranges',
        secondBody: 'pears and grapes',
      );
      expect(await document.search('kiwi'), isEmpty);
    },
  );

  test(
    'a hit returns an EpubLocator, the chapter title, and a contextual excerpt',
    () async {
      const prefix =
          'a quiet morning over the harbour while the gulls slept on the pier';
      const suffix =
          'then the bells rang from the chapel on the hill above the village';
      final document = makeDocument(
        firstBody: '$prefix needle $suffix',
        firstTitle: 'prologue',
      );

      final hits = await document.search('needle');
      expect(hits, hasLength(1));
      final hit = hits.single;
      expect(hit.title, 'prologue');
      final locator = hit.locator;
      expect(locator, isA<EpubLocator>());
      expect((locator as EpubLocator).href, 'oebps/ch1.xhtml');
      expect(locator.fragment, isNull);
      expect(hit.excerpt, contains('needle'));
      // Excerpt should be at least as long as the query itself and trimmed.
      expect(hit.excerpt.trim(), isNot(equals('')));
    },
  );

  test('hits across chapters each point at their own href', () async {
    final document = makeDocument(
      firstBody: 'lorem ipsum dolor sit amet',
      secondBody: 'lorem ipsum begins again',
      firstTitle: 'alpha',
      secondTitle: 'beta',
    );

    final hits = await document.search('lorem');
    expect(hits, hasLength(2));
    final hrefs = hits
        .map((h) => (h.locator as EpubLocator).href)
        .toList(growable: false);
    expect(hrefs, ['oebps/ch1.xhtml', 'oebps/ch2.xhtml']);
    expect(hits.map((h) => h.title), ['alpha', 'beta']);
    for (final hit in hits) {
      expect(hit.excerpt, contains('lorem'));
    }
  });

  test('repeated matches inside a chapter collapse to a single hit', () async {
    final document = makeDocument(
      firstBody: 'needle one then needle two then needle three',
      secondBody: 'unrelated body content',
    );

    final hits = await document.search('needle');
    expect(hits, hasLength(1));
    expect((hits.single.locator as EpubLocator).href, 'oebps/ch1.xhtml');
  });

  test('chapter title falls back to the book metadata when the chapter body '
      'first line exceeds the title rune cap', () async {
    // `_firstLine` returns '' when the body first line exceeds 40 runes,
    // which makes `EpubReaderDocument.search` use `metadata.title` as the
    // fallback title for the hit.
    final longFirstLine = 'x' * 80;
    final document = makeDocument(
      firstBody: '$longFirstLine\nneedle deep in the body\nmore text',
      firstTitle: '',
    );

    final hits = await document.search('needle');
    expect(hits, hasLength(1));
    expect(hits.single.title, metadata.title);
    expect((hits.single.locator as EpubLocator).href, 'oebps/ch1.xhtml');
    expect(hits.single.excerpt, contains('needle'));
  });
}
