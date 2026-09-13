import 'dart:convert';

import 'package:app/features/tools/ai/model_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAiCompatibleClient.chatCompletionsUrl', () {
    test('appends /v1/chat/completions to a bare host', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUrl('https://api.deepseek.com'),
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('appends only /chat/completions when /v1 is already present', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUrl('https://x.local/v1'),
        'https://x.local/v1/chat/completions',
      );
    });

    test('keeps /chat/completions intact when already present', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUrl(
          'https://x.local/v1/chat/completions',
        ),
        'https://x.local/v1/chat/completions',
      );
    });

    test('strips a trailing slash before normalising the path', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUrl('https://x.local/'),
        'https://x.local/v1/chat/completions',
      );
    });
  });

  group('OpenAiCompatibleClient.complete', () {
    test(
      'POSTs to the chat completions URL with the expected payload',
      () async {
        late http.Request seen;
        final client = MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '  hello world  '},
                },
              ],
            }),
            200,
          );
        });
        final model = OpenAiCompatibleClient(
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          httpClient: client,
        );
        final text = await model.complete(const [
          {'role': 'system', 'content': 'you are an assistant'},
          {'role': 'user', 'content': 'hi'},
        ]);
        expect(text, 'hello world');
        expect(seen.method, 'POST');
        expect(
          seen.url.toString(),
          'https://api.deepseek.com/v1/chat/completions',
        );
        expect(seen.headers['content-type'], 'application/json');
        expect(seen.headers['authorization'], isNull);
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-chat');
        expect(body['temperature'], 0.2);
        expect(body['messages'], hasLength(2));
      },
    );

    test('sends a Bearer header when an api key is configured', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'ok'},
              },
            ],
          }),
          200,
        );
      });
      final model = OpenAiCompatibleClient(
        endpoint: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: '  sk-test  ',
        httpClient: client,
      );
      await model.complete(const [
        {'role': 'user', 'content': 'hi'},
      ]);
      expect(seen.headers['authorization'], 'Bearer sk-test');
    });

    test('throws StateError on non-2xx responses', () async {
      final client = MockClient((_) async => http.Response('nope', 503));
      final model = OpenAiCompatibleClient(
        endpoint: 'https://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('throws FormatException when the body is not an object', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(['nope']), 200),
      );
      final model = OpenAiCompatibleClient(
        endpoint: 'https://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('throws FormatException when choices is missing or empty', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'choices': []}), 200),
      );
      final model = OpenAiCompatibleClient(
        endpoint: 'https://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('throws FormatException when message content is empty', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '   '},
              },
            ],
          }),
          200,
        ),
      );
      final model = OpenAiCompatibleClient(
        endpoint: 'https://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('throws FormatException when message is missing entirely', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [{}],
          }),
          200,
        ),
      );
      final model = OpenAiCompatibleClient(
        endpoint: 'https://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });
  });

  group('ReaderServerAiClient.complete', () {
    test('POSTs to /v1/ai/chat and reads the content field', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'content': '  服务端响应  '})),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final model = ReaderServerAiClient(
        baseUrl: 'http://127.0.0.1:8787',
        model: 'deepseek-chat',
        apiKey: 'sk-client',
        provider: 'deepseek',
        httpClient: client,
      );
      expect(
        await model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        '服务端响应',
      );
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://127.0.0.1:8787/v1/ai/chat');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-chat');
      expect(body['provider'], 'deepseek');
      expect(body['api_key'], 'sk-client');
    });

    test('omits the api_key field when none is configured', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'content': 'ok'}), 200);
      });
      final model = ReaderServerAiClient(
        baseUrl: 'http://127.0.0.1:8787',
        model: 'deepseek-chat',
        httpClient: client,
      );
      await model.complete(const [
        {'role': 'user', 'content': 'hi'},
      ]);
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body.containsKey('api_key'), isFalse);
    });

    test('strips a trailing slash on the base URL', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'content': 'ok'}), 200);
      });
      final model = ReaderServerAiClient(
        baseUrl: 'http://127.0.0.1:8787/',
        model: 'deepseek-chat',
        httpClient: client,
      );
      await model.complete(const [
        {'role': 'user', 'content': 'hi'},
      ]);
      expect(seen.url.toString(), 'http://127.0.0.1:8787/v1/ai/chat');
    });

    test('throws StateError on non-2xx responses', () async {
      final client = MockClient((_) async => http.Response('nope', 502));
      final model = ReaderServerAiClient(
        baseUrl: 'http://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('throws FormatException when the body is not an object', () async {
      final client = MockClient((_) async => http.Response('"text"', 200));
      final model = ReaderServerAiClient(
        baseUrl: 'http://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('throws FormatException when content is missing or blank', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'content': '   '}), 200),
      );
      final model = ReaderServerAiClient(
        baseUrl: 'http://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('throws FormatException when content is not a string', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'content': 42}), 200),
      );
      final model = ReaderServerAiClient(
        baseUrl: 'http://x',
        model: 'm',
        httpClient: client,
      );
      await expectLater(
        model.complete(const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });
  });

  group('RecordingModelClient', () {
    test('records the messages and returns the configured reply', () async {
      final client = RecordingModelClient(reply: 'ok');
      final messages = [
        {'role': 'user', 'content': 'hi'},
      ];
      final result = await client.complete(messages);
      expect(result, 'ok');
      expect(client.calls, 1);
      expect(client.lastMessages, same(messages));
    });

    test('invokes the optional onComplete callback', () async {
      final captured = <List<Map<String, String>>>[];
      final client = RecordingModelClient(reply: 'r', onComplete: captured.add);
      await client.complete(const [
        {'role': 'user', 'content': 'hi'},
      ]);
      expect(captured, hasLength(1));
    });
  });
}
