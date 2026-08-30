import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_notes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a note jump uses the quote and keeps a missing locator missing', () {
    final jump = noteJump(
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: '  hello from notes  ',
        locatorLabel: encodeLocator(const EpubLocator(href: 'OEBPS/ch2.xhtml')),
        source: userNoteSource,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(jump.scrollQuote, 'hello from notes');
    expect(jump.locator, isA<EpubLocator>());
    expect((jump.locator as EpubLocator).href, 'OEBPS/ch2.xhtml');
  });

  test('an empty quote does not invent a scroll target', () {
    final jump = noteJump(
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: '   ',
        locatorLabel: encodeLocator(const EpubLocator(href: 'OEBPS/ch1.xhtml')),
        source: userNoteSource,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(jump.scrollQuote, isNull);
    expect(jump.locator, isA<EpubLocator>());
  });

  test('a missing locator stays missing', () {
    final jump = noteJump(
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'hello from notes',
        locatorLabel: '',
        source: userNoteSource,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(jump.locator, isNull);
    expect(jump.scrollQuote, 'hello from notes');
  });
}
