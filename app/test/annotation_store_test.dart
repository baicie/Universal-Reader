import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves a note per book and does not invent another book', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesAnnotationRepository(
      await SharedPreferences.getInstance(),
    );
    final note = ReaderAnnotation(
      id: '1',
      note: 'saved reply',
      quote: 'what is white?',
      locatorLabel: 'chapter-4',
      createdAt: DateTime.utc(2026, 8, 29),
    );

    await store.append('design', note);

    expect((await store.load('design')).single.note, 'saved reply');
    expect(await store.load('other'), isEmpty);
  });

  test('corrupt annotation json is an error, not an empty list', () async {
    SharedPreferences.setMockInitialValues({
      '${SharedPreferencesAnnotationRepository.prefix}design': '{not-json',
    });
    final store = SharedPreferencesAnnotationRepository(
      await SharedPreferences.getInstance(),
    );

    expect(store.load('design'), throwsA(isA<FormatException>()));
  });

  test(
    'removing a note does not touch the conversation or another book',
    () async {
      final notes = InMemoryAnnotationRepository();
      final talks = InMemoryConversationRepository();
      await notes.append(
        'notes.txt',
        ReaderAnnotation(
          id: 'n1',
          note: 'keep',
          quote: 'hello from notes',
          source: userNoteSource,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await notes.append(
        'other.txt',
        ReaderAnnotation(
          id: 'n2',
          note: 'other',
          quote: 'elsewhere',
          source: userNoteSource,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await talks.append(
        'notes.txt',
        ConversationTurn(
          kind: ReaderToolKind.ask,
          question: '这句话什么意思？',
          reply: '它在讲留白。',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await notes.remove('notes.txt', 'n1');

      expect(await notes.load('notes.txt'), isEmpty);
      expect((await notes.load('other.txt')).single.id, 'n2');
      expect(await talks.load('notes.txt'), hasLength(1));
    },
  );
}
