import 'dart:convert';

import 'package:app/core/http_library_repository.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/ai/model_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local library keeps conversations on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final runtime = await resolveAiRuntime(
      InMemoryLibraryRepository(),
      preferences,
    );

    expect(runtime.useGateway, isFalse);
    expect(runtime.serverHasKey, isFalse);
    expect(
      runtime.conversations,
      isA<SharedPreferencesConversationRepository>(),
    );
  });

  test('remote library uses the rust gateway and conversation API', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/ai/status') {
        return http.Response(
          '{ "configured": true, "provider": "deepseek" }',
          200,
        );
      }
      return http.Response('missing', 404);
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final runtime = await resolveAiRuntime(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      preferences,
      httpClient: client,
    );

    expect(runtime.useGateway, isTrue);
    expect(runtime.serverHasKey, isTrue);
    expect(runtime.conversations, isA<HttpConversationRepository>());
  });

  test('reader server client reads the gateway content field', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/ai/chat');
      expect(request.body, contains('deepseek-chat'));
      expect(request.body, contains('"api_key":"sk-client"'));
      expect(request.body, isNot(contains('endpoint')));
      return http.Response.bytes(
        utf8.encode('{"content":"只谈当前摘录。"}'),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final model = ReaderServerAiClient(
      baseUrl: 'http://127.0.0.1:8787',
      model: 'deepseek-chat',
      apiKey: 'sk-client',
      httpClient: client,
    );

    expect(
      await model.complete(const [
        {'role': 'user', 'content': 'hi'},
      ]),
      '只谈当前摘录。',
    );
  });

  test('remote library without a server key still uses the gateway', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/ai/status') {
        return http.Response('{ "configured": false }', 200);
      }
      return http.Response('missing', 404);
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final runtime = await resolveAiRuntime(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      preferences,
      httpClient: client,
    );

    expect(runtime.useGateway, isTrue);
    expect(runtime.serverHasKey, isFalse);
    expect(runtime.allowMissingApiKey, isFalse);
  });

  test('unreachable ai status does not disable the gateway', () async {
    final client = MockClient((request) async {
      return http.Response('no', 500);
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final runtime = await resolveAiRuntime(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      preferences,
      httpClient: client,
    );

    expect(runtime.useGateway, isTrue);
    expect(runtime.serverHasKey, isFalse);
  });

  test('gateway runtime builds a server client', () {
    final runtime = AiRuntime(
      useGateway: true,
      baseUrl: 'http://127.0.0.1:8787',
      serverHasKey: true,
      conversations: InMemoryConversationRepository(),
    );

    expect(runtime.allowMissingApiKey, isTrue);
    expect(
      runtime.modelClient(const AiSettings(model: 'deepseek-chat')),
      isA<ReaderServerAiClient>(),
    );
  });
}
