import 'package:app/core/epub_document.dart';
import 'package:app/core/foliate_bridge.dart';
import 'package:app/core/foliate_session.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  EpubReaderDocument document() {
    return EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(
        firstBody: List.filled(
          8,
          'hello from epub paginated chapter text. ',
        ).join(),
      ),
    );
  }

  test('opens a chapter as a paged foliate session with a cfi', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(1));
    expect(session.currentCfi, contains('epubcfi('));
    expect(session.progression, 0);
    final command = FoliateBridge.openSession(session);
    expect(command['type'], 'open');
    expect(command['cfi'], session.currentCfi);
    expect(command['pageCount'], session.pageCount);
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('next page advances cfi progression', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    final first = session.currentCfi;
    expect(session.next(), isTrue);
    expect(session.currentCfi, isNot(first));
    expect(session.progression, greaterThan(0));
  });

  test('selection events without text stay missing', () {
    final session = FoliateSession.open(document(), pageCharLimit: 80);
    expect(
      session.selectionFromEvent({'type': 'selection', 'text': '  '}),
      isNull,
    );
    final hit = session.selectionFromEvent({
      'type': 'selection',
      'text': 'hello from epub',
      'cfi': session.currentCfi,
    });
    expect(hit!.quote, 'hello from epub');
    expect(hit.cfi, session.currentCfi);
  });
}
