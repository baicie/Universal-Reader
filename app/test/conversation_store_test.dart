import 'dart:convert';

import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final turn = ConversationTurn(
    kind: ReaderToolKind.ask,
    question: '这句话什么意思？',
    reply: '它在讲留白。',
    locatorLabel: 'Offset 12',
    createdAt: DateTime.utc(2026, 8, 29, 1, 30),
  );

  test('in-memory conversation store keeps turns for one book', () async {
    final store = InMemoryConversationRepository();
    await store.save('notes.txt', [turn]);

    final loaded = await store.load('notes.txt');
    expect(loaded, hasLength(1));
    expect(loaded.single.question, '这句话什么意思？');
    expect(loaded.single.reply, '它在讲留白。');
    expect(await store.load('other'), isEmpty);
  });

  test('shared preferences conversation store round-trips turns', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesConversationRepository(preferences);
    await store.save('design', [turn]);

    final loaded = await SharedPreferencesConversationRepository(preferences)
        .load('design');
    expect(loaded.single.kind, ReaderToolKind.ask);
    expect(loaded.single.reply, '它在讲留白。');
    expect(loaded.single.createdAt, turn.createdAt);
  });

  test('parses rust snake_case conversation json', () {
    final parsed = ConversationTurn.fromJson({
      'kind': 'explain',
      'question': '',
      'reply': '留白',
      'locator_label': 'Offset 3',
      'created_at_ms': 1,
    });
    expect(parsed.kind, ReaderToolKind.explain);
    expect(parsed.locatorLabel, 'Offset 3');
    expect(parsed.createdAt.millisecondsSinceEpoch, 1);
  });

  test('http conversation store round-trips turns for one book', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(
            '{"turns":[{"kind":"ask","question":"这句话什么意思？","reply":"它在讲留白。","locator_label":"Offset 12","created_at_ms":1}]}',
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'PUT') {
        return http.Response('{"turns":[]}', 200);
      }
      return http.Response('missing', 404);
    });
    final store = HttpConversationRepository(
      baseUrl: 'http://127.0.0.1:8787',
      httpClient: client,
    );

    final loaded = await store.load('notes');
    expect(loaded.single.reply, '它在讲留白。');

    await store.save('notes', [turn]);
    expect(requests.last.method, 'PUT');
    expect(requests.last.url.path, '/v1/library/documents/notes/conversations');
    expect(requests.last.body, contains('locator_label'));
    expect(requests.last.body, contains('created_at_ms'));
  });

  test('append keeps only the latest 50 turns', () {
    final turns = [
      for (var i = 0; i < 51; i++)
        ConversationTurn(
          kind: ReaderToolKind.summarize,
          reply: 'r$i',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        ),
    ];
    final trimmed = trimConversation(turns);
    expect(trimmed, hasLength(50));
    expect(trimmed.first.reply, 'r1');
    expect(trimmed.last.reply, 'r50');
  });

  test('service json uses snake_case fields', () {
    expect(turn.toServiceJson()['locator_label'], 'Offset 12');
    expect(
      turn.toServiceJson()['created_at_ms'],
      turn.createdAt.millisecondsSinceEpoch,
    );
  });

  test('shared preferences conversation store does not treat corrupt json as empty', () async {
    SharedPreferences.setMockInitialValues({
      '${SharedPreferencesConversationRepository.storagePrefix}design':
          '{not-json',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesConversationRepository(preferences);
    expect(store.load('design'), throwsA(isA<FormatException>()));
  });

  test(
    'http conversation store does not treat a malformed body as empty',
    () async {
      final client = MockClient((request) async {
        return http.Response('{"turns":"nope"}', 200);
      });
      final store = HttpConversationRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      );
      expect(store.load('notes'), throwsA(isA<FormatException>()));
    },
  );

  test('http conversation store surfaces non-404 failures', () async {
    final client = MockClient((request) async {
      return http.Response('error', 500);
    });
    final store = HttpConversationRepository(
      baseUrl: 'http://127.0.0.1:8787',
      httpClient: client,
    );
    expect(store.load('notes'), throwsA(isA<FormatException>()));
  });
}
