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
    expect(command['fontSize'], 18);
    expect(command['lineHeight'], 1.7);
    expect(command['fontFamily'], contains('serif'));
    expect(command['background'], '#F5F0E8');
    expect(command['color'], '#2A2620');
    expect(FoliateBridge.openSession(session, fontSize: 22)['fontSize'], 22);
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('next page advances cfi progression', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    final first = session.currentCfi;
    expect(session.next(), isTrue);
    expect(session.currentCfi, isNot(first));
    expect(session.progression, greaterThan(0));
  });

  test('goToLastPage lands on the final page', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(1));
    session.goToLastPage();
    expect(session.pageIndex, session.pageCount - 1);
    expect(session.next(), isFalse);
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

  test('relocated from the host replaces character pages', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(1));
    final charCount = session.pageCount;
    expect(
      session.applyRelocated({
        'type': 'relocated',
        'pageIndex': 2,
        'pageCount': 5,
      }),
      isTrue,
    );
    expect(session.pageCount, 5);
    expect(session.pageIndex, 2);
    expect(session.next(), isTrue);
    expect(session.pageIndex, 3);
    session.goToLastPage();
    expect(session.pageIndex, 4);
    expect(session.next(), isFalse);
    expect(session.pageCount, isNot(charCount));
  });

  test('a relocated event without page count keeps character pages', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    final charCount = session.pageCount;
    expect(
      session.applyRelocated({'type': 'relocated', 'pageIndex': 1}),
      isFalse,
    );
    expect(
      session.applyRelocated({'type': 'selection', 'pageCount': 9}),
      isFalse,
    );
    expect(session.pageCount, charCount);
    expect(session.pageIndex, 0);
  });

  test('previous page walks back and rejects the first page', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(2));
    expect(session.previous(), isFalse);
    expect(session.pageIndex, 0);
    session.next();
    session.next();
    final mid = session.pageIndex;
    expect(session.previous(), isTrue);
    expect(session.pageIndex, mid - 1);
    session.goToPage(0);
    expect(session.previous(), isFalse);
    expect(session.pageIndex, 0);
  });

  test('goToCfi jumps to the page whose start offset lands first', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(2));
    final midStart = session.pages[1].startOffset;
    final laterStart = session.pages[2].startOffset;
    expect(session.goToCfi('epubcfi(xhtml:$midStart)'), isTrue);
    expect(session.pageIndex, 1);
    expect(session.goToCfi('epubcfi(xhtml:$laterStart)'), isTrue);
    expect(session.pageIndex, 2);
    expect(session.goToCfi('not a cfi'), isFalse);
    expect(session.pageIndex, 2);
  });

  test('goToPage clamps out-of-range and negative indices', () {
    final session = FoliateSession.open(document(), pageCharLimit: 40);
    expect(session.pageCount, greaterThan(1));
    session.goToPage(-3);
    expect(session.pageIndex, 0);
    session.goToPage(session.pageCount + 5);
    expect(session.pageIndex, session.pageCount - 1);
    session.goToPage(1);
    expect(session.pageIndex, 1);
  });

  test('paginateReflow keeps short text as a single page', () {
    final pages = paginateReflow(
      text: 'short text',
      html: '<p>short text</p>',
      pageCharLimit: 2000,
    );
    expect(pages, hasLength(1));
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, 'short text'.length);
    expect(pages.single.html, '<p>short text</p>');
  });

  test('paginateReflow turns empty text into a single empty page', () {
    final pages = paginateReflow(
      text: '',
      html: '<p></p>',
      pageCharLimit: 2000,
    );
    expect(pages, hasLength(1));
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, 0);
    expect(pages.single.html, '<p></p>');
  });

  test('paginateReflow breaks long text at the last whitespace', () {
    // 'aabbcc dd ee': whitespace at indices 6 and 9. With limit=10, the
    // first slice extends to index 10 (after the last whitespace) so the
    // first page holds 'aabbcc dd' and the loop resumes at the next
    // character.
    final pages = paginateReflow(
      text: 'aabbcc dd ee',
      html: '<p>aabbcc dd ee</p>',
      pageCharLimit: 10,
    );
    expect(pages, hasLength(2));
    expect(pages[0].endOffset, 10);
    expect(pages[0].html, '<p>aabbcc dd</p>');
    expect(pages[1].startOffset, 10);
    expect(pages[1].endOffset, 12);
    expect(pages[1].html, '<p>ee</p>');
  });

  test('paginateReflow falls back to end-of-slice when there is no whitespace',
      () {
    // 50 chars, no whitespace → each slice ends at start+pageCharLimit.
    final text = 'x' * 50;
    final pages = paginateReflow(
      text: text,
      html: '',
      pageCharLimit: 10,
    );
    expect(pages, hasLength(5));
    expect(pages[0].startOffset, 0);
    expect(pages[0].endOffset, 10);
    expect(pages[4].startOffset, 40);
    expect(pages[4].endOffset, 50);
    expect(pages.every((p) => p.html.startsWith('<p>')), isTrue);
  });

  test('paginateReflow advances past short pages', () {
    // With pageCharLimit=1, each page holds one character, including the
    // space at index 1 (which trims to an empty <p></p>).
    final pages = paginateReflow(
      text: 'a b',
      html: '',
      pageCharLimit: 1,
    );
    expect(pages, hasLength(3));
    expect(pages.map((p) => p.startOffset).toList(), [0, 1, 2]);
    expect(pages.map((p) => p.endOffset).toList(), [1, 2, 3]);
    expect(pages.last.endOffset, 3);
  });
}
