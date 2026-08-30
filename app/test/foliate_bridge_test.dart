import 'dart:io';

import 'package:app/core/epub_document.dart';
import 'package:app/core/foliate_bridge.dart';
import 'package:app/core/foliate_session.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  test('opens a chapter through the foliate command protocol', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    final command = FoliateBridge.openCurrent(document);
    expect(command['type'], 'open');
    expect(command['href'], isNotEmpty);
    expect(command['html'], contains('hello from epub'));
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('open command keeps chapter images instead of a sliced paragraph', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: illustratedEpubBytes(
        firstBody: List.filled(
          80,
          'hello from epub paginated chapter text. ',
        ).join(),
      ),
    );
    final command = FoliateBridge.openCurrent(document);
    expect(command['html'], contains('<img'));
    expect(command['html'], contains('class="caption"'));
    expect(command['html'], contains('data:image/png'));
    expect(command['html'], isNot(contains('&lt;img')));
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('open command carries chapter quotes without inventing one', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    final command = FoliateBridge.openSession(
      FoliateSession.open(document),
      quotes: ['hello from notes'],
    );
    expect(command['quotes'], ['hello from notes']);
    expect(FoliateBridge.openCurrent(document)['quotes'], isEmpty);
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('host executes open commands and posts selection without a CDN', () {
    final html = File('assets/reader/foliate/host.html').readAsStringSync();
    expect(html, contains("data.type === 'open'"));
    expect(html, contains('selectionchange'));
    expect(html, contains('fontSize'));
    expect(html, contains('command.lineHeight'));
    expect(html, contains('command.fontFamily'));
    expect(html, contains('command.background'));
    expect(html, contains('command.color'));
    expect(html.toLowerCase(), isNot(contains('cdn.jsdelivr')));
    expect(html, isNot(contains('unpkg.com')));
    expect(html, contains("import('./paginator.js')"));
    expect(html, contains('foliate-paginator'));
    expect(html, contains("addEventListener('relocate'"));
    expect(html, contains('goToPage'));
    expect(html, contains('pages - 2'));
    expect(html, contains('paintQuotes'));
    expect(html, contains('data-foliate-quote'));
    expect(html, contains('a[href]'));
    expect(html, contains('preventDefault'));
    expect(html, contains("'link'"));
    expect(html, contains('goToFragment'));
    expect(html, contains('getElementById'));
    expect(html, contains('goToQuote'));
    expect(File('assets/reader/foliate/paginator.js').existsSync(), isTrue);
  });

  test('open command carries a fragment without inventing one', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    final session = FoliateSession.open(document);
    expect(FoliateBridge.openSession(session).containsKey('fragment'), isFalse);
    expect(
      FoliateBridge.openSession(session, fragment: 'note')['fragment'],
      'note',
    );
  });

  test('open command carries a scroll quote without inventing one', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    final session = FoliateSession.open(document);
    expect(
      FoliateBridge.openSession(session).containsKey('scrollQuote'),
      isFalse,
    );
    expect(
      FoliateBridge.openSession(session, scrollQuote: 'hello from epub')['scrollQuote'],
      'hello from epub',
    );
  });
}
