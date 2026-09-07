import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_notes.dart';
import 'package:app/features/reader/reader_selection.dart';
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

  group('noteListLabel', () {
    test('prefers the trimmed quote when present', () {
      final note = ReaderAnnotation(
        id: 'n1',
        note: 'fallback body',
        quote: '  quoted excerpt  ',
        locatorLabel: 'chapter-4',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(noteListLabel(note), 'quoted excerpt');
    });

    test('falls back to the body when the quote is blank', () {
      final note = ReaderAnnotation(
        id: 'n1',
        note: '  fallback body  ',
        quote: '   ',
        locatorLabel: 'chapter-4',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(noteListLabel(note), 'fallback body');
    });

    test('falls back to the locator label when both quote and body are empty',
        () {
      final note = ReaderAnnotation(
        id: 'n1',
        note: '',
        quote: '',
        locatorLabel: 'chapter-1',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(noteListLabel(note), 'chapter-1');
    });
  });

  group('noteFromSelection', () {
    test('returns null for a blank selection', () {
      expect(noteFromSelection(''), isNull);
      expect(noteFromSelection('   '), isNull);
    });

    test('returns a user note with the trimmed quote and locator', () {
      final note = noteFromSelection(
        '  白是一种包容  ',
        locatorLabel: 'chapter-4',
        now: DateTime.utc(2026, 9, 7),
      );
      expect(note, isNotNull);
      expect(note!.source, userNoteSource);
      expect(note.quote, '白是一种包容');
      expect(note.locatorLabel, 'chapter-4');
      expect(note.note, isEmpty);
    });

    test('carries optional body text', () {
      final note = noteFromSelection(
        ' excerpt ',
        note: '我的笔记',
        now: DateTime.utc(2026, 9, 7),
      );
      expect(note!.note, '我的笔记');
      expect(note.quote, 'excerpt');
    });
  });
}
