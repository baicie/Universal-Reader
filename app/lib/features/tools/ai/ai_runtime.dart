import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/http_library_repository.dart';
import '../../../core/library_repository.dart';
import '../../../core/sqlite_library_repository.dart';
import '../../library/annotation_store.dart';
import 'ai_settings.dart';
import 'conversation_store.dart';
import 'model_client.dart';

class AiRuntime {
  AiRuntime({
    required this.useGateway,
    required this.baseUrl,
    required this.serverHasKey,
    required this.conversations,
    AnnotationRepository? annotations,
  }) : annotations = annotations ?? InMemoryAnnotationRepository();

  factory AiRuntime.local(
    ConversationRepository conversations, {
    AnnotationRepository? annotations,
  }) {
    return AiRuntime(
      useGateway: false,
      baseUrl: '',
      serverHasKey: false,
      conversations: conversations,
      annotations: annotations,
    );
  }

  final bool useGateway;
  final String baseUrl;
  final bool serverHasKey;
  final ConversationRepository conversations;
  final AnnotationRepository annotations;

  bool get allowMissingApiKey => useGateway && serverHasKey;

  ModelClient modelClient(AiSettings settings) {
    final resolved = settings.withProjectDefaults();
    if (useGateway) {
      return ReaderServerAiClient(
        baseUrl: baseUrl,
        model: resolved.model,
        apiKey: resolved.apiKey,
        provider: resolved.provider.name,
      );
    }
    return OpenAiCompatibleClient(
      endpoint: resolved.endpoint,
      model: resolved.model,
      apiKey: resolved.apiKey,
    );
  }
}

Future<AiRuntime> resolveAiRuntime(
  LibraryRepository library,
  SharedPreferences preferences, {
  http.Client? httpClient,
}) async {
  if (library is! HttpLibraryRepository) {
    return AiRuntime.local(
      SharedPreferencesConversationRepository(preferences),
      annotations: library is SqliteLibraryRepository
          ? SqliteAnnotationRepository(library)
          : SharedPreferencesAnnotationRepository(preferences),
    );
  }
  final client = httpClient ?? library.httpClient;
  var serverHasKey = false;
  try {
    final response = await client
        .get(library.uri('/v1/ai/status'))
        .timeout(const Duration(milliseconds: 800));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final providers = decoded['providers'];
        serverHasKey =
            decoded['configured'] == true ||
            (providers is Map && providers['deepseek'] == true);
      }
    }
  } catch (_) {
    // 服务尚未提供 /v1/ai/status 或暂时不可达时，按未配置密钥处理。
  }
  return AiRuntime(
    useGateway: true,
    baseUrl: library.baseUrl,
    serverHasKey: serverHasKey,
    conversations: HttpConversationRepository(
      baseUrl: library.baseUrl,
      httpClient: client,
    ),
    annotations: HttpAnnotationRepository(
      baseUrl: library.baseUrl,
      httpClient: client,
    ),
  );
}
