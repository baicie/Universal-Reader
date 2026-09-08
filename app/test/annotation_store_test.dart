import 'dart:convert';

import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('SharedPreferencesAnnotationRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('load returns an empty list when nothing is stored', () async {
      final store = SharedPreferencesAnnotationRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await store.load('design'), isEmpty);
    });

    test('load treats an empty stored value as no notes', () async {
      SharedPreferences.setMockInitialValues({
        '${SharedPreferencesAnnotationRepository.prefix}design': '',
      });
      final store = SharedPreferencesAnnotationRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await store.load('design'), isEmpty);
    });

    test('persists and reloads the notes list', () async {
      final store = SharedPreferencesAnnotationRepository(
        await SharedPreferences.getInstance(),
      );
      await store.save('design', [
        ReaderAnnotation(
          id: 'a',
          note: 'first',
          source: userNoteSource,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        ReaderAnnotation(
          id: 'b',
          note: 'second',
          source: bookmarkSource,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ]);
      final loaded = await store.load('design');
      expect(loaded.map((n) => n.id), ['a', 'b']);
      expect(loaded[1].source, bookmarkSource);
    });
  });

  group('InMemoryAnnotationRepository', () {
    test('starts empty for any document', () async {
      final store = InMemoryAnnotationRepository();
      expect(await store.load('design'), isEmpty);
    });

    test('save and load round-trip the notes list', () async {
      final store = InMemoryAnnotationRepository();
      await store.save('design', [
        ReaderAnnotation(
          id: 'a',
          note: 'first',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      expect((await store.load('design')).single.id, 'a');
    });

    test('load returns a defensive copy', () async {
      final store = InMemoryAnnotationRepository();
      await store.append(
        'design',
        ReaderAnnotation(
          id: 'a',
          note: 'first',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final list = await store.load('design');
      list.clear();
      expect((await store.load('design')).single.id, 'a');
    });
  });

  group('HttpAnnotationRepository', () {
    test('load PUTs the trailing slash on the base URL', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'notes': []}), 200);
      });
      final store = HttpAnnotationRepository(
        baseUrl: 'http://127.0.0.1:8787/',
        httpClient: client,
      );
      expect(await store.load('design'), isEmpty);
      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'http://127.0.0.1:8787/v1/library/documents/design/annotations',
      );
    });

    test('load accepts a notes map without a top-level list', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode([]), 200),
      );
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      expect(await store.load('design'), isEmpty);
    });

    test('load parses notes wrapped in a notes field', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'notes': [
              {
                'id': 'a',
                'note': 'reply',
                'created_at_ms': DateTime.utc(
                  2026,
                  1,
                  1,
                ).millisecondsSinceEpoch,
              },
            ],
          }),
          200,
        ),
      );
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      final loaded = await store.load('design');
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'a');
    });

    test('load throws on non-200 responses', () async {
      final client = MockClient((_) async => http.Response('nope', 503));
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      await expectLater(store.load('design'), throwsFormatException);
    });

    test('save PUTs the trimmed notes list as JSON', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response('{}', 200);
      });
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      await store.save('design', [
        ReaderAnnotation(
          id: 'a',
          note: 'first',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        ReaderAnnotation(
          id: 'b',
          note: 'second',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ]);
      expect(seen.method, 'PUT');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['notes'], isA<List>());
      expect((body['notes'] as List).length, 2);
    });

    test('save throws on non-200 responses', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      await expectLater(
        store.save('design', [
          ReaderAnnotation(
            id: 'a',
            note: 'first',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ]),
        throwsFormatException,
      );
    });

    test('load encodes ids with spaces or special characters', () async {
      // Spaces and '#' in an id must not corrupt the URL path.
      late String seenPath;
      final client = MockClient((req) async {
        seenPath = req.url.path;
        return http.Response(jsonEncode({'notes': []}), 200);
      });
      final store = HttpAnnotationRepository(
        baseUrl: 'http://x',
        httpClient: client,
      );
      await store.load('my book #1.epub');
      expect(
        seenPath,
        '/v1/library/documents/${Uri.encodeComponent('my book #1.epub')}/annotations',
      );
    });
  });

  group('ReaderAnnotation JSON', () {
    test('round-trips through toServiceJson / fromJson', () {
      final original = ReaderAnnotation(
        id: 'a',
        note: 'reply',
        quote: 'snippet',
        locatorLabel: 'chapter-4',
        source: assistantNoteSource,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final encoded = jsonEncode(original.toServiceJson());
      final decoded = ReaderAnnotation.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.id, original.id);
      expect(decoded.note, original.note);
      expect(decoded.quote, original.quote);
      expect(decoded.locatorLabel, original.locatorLabel);
      expect(decoded.source, original.source);
      expect(decoded.createdAt, original.createdAt);
    });

    test('fromJson defaults to assistant source when missing', () {
      final annotation = ReaderAnnotation.fromJson({
        'id': 'a',
        'note': 'r',
        'createdAtMs': 1,
      });
      expect(annotation.source, assistantNoteSource);
    });

    test('fromJson accepts created_at_ms snake_case', () {
      final annotation = ReaderAnnotation.fromJson({
        'id': 'a',
        'note': 'r',
        'created_at_ms': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      });
      expect(annotation.createdAt, DateTime.utc(2026, 1, 1));
    });

    test(
      'fromJson defaults optional fields to empty strings when id is present',
      () {
        // id is required; note/quote/locatorLabel are optional.
        final annotation = ReaderAnnotation.fromJson({
          'id': 'a',
          'createdAtMs': 1,
        });
        expect(annotation.note, '');
        expect(annotation.quote, '');
        expect(annotation.locatorLabel, '');
      },
    );

    test('fromJson throws when id is missing', () {
      expect(
        () => ReaderAnnotation.fromJson({'note': 'r', 'createdAtMs': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseAnnotations', () {
    test('throws when the value is not a list', () {
      expect(() => parseAnnotations('not a list'), throwsFormatException);
    });

    test('throws when an item is not a map', () {
      expect(() => parseAnnotations(['nope']), throwsFormatException);
    });

    test('parses each entry into a ReaderAnnotation', () {
      final list = parseAnnotations([
        {
          'id': 'a',
          'note': 'first',
          'createdAtMs': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        },
        {
          'id': 'b',
          'note': 'second',
          'createdAtMs': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        },
      ]);
      expect(list.map((n) => n.id), ['a', 'b']);
    });
  });

  group('trimAnnotations', () {
    test('keeps the list untouched when shorter than the cap', () {
      final notes = [
        for (var i = 0; i < 5; i++)
          ReaderAnnotation(
            id: '$i',
            note: 'n',
            createdAt: DateTime.utc(2026, 1, i + 1),
          ),
      ];
      expect(trimAnnotations(notes).length, 5);
    });

    test('drops the oldest entries once the cap is reached', () {
      final notes = [
        for (var i = 0; i < maxAnnotations + 5; i++)
          ReaderAnnotation(
            id: '$i',
            note: 'n',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
      ];
      final trimmed = trimAnnotations(notes);
      expect(trimmed.length, maxAnnotations);
      expect(trimmed.first.id, '5');
      expect(trimmed.last.id, '${maxAnnotations + 4}');
    });
  });
}
