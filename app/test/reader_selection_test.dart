import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty selection does not become a note', () {
    expect(noteFromSelection('   '), isNull);
    expect(noteFromSelection(''), isNull);
  });

  test('a confirmed quote becomes a user note', () {
    final note = noteFromSelection(
      '  hello from notes  ',
      locatorLabel: 'text:0',
      now: DateTime.utc(2026, 1, 2),
    );
    expect(note, isNotNull);
    expect(note!.quote, 'hello from notes');
    expect(note.source, userNoteSource);
    expect(note.locatorLabel, 'text:0');
  });

  test('appending a selection note does not invent another book', () async {
    final store = InMemoryAnnotationRepository();
    final note = noteFromSelection('hello from notes', locatorLabel: 'text:0')!;
    await store.append('notes.txt', note);
    expect((await store.load('notes.txt')).single.source, userNoteSource);
    expect(await store.load('other.txt'), isEmpty);
  });
}
