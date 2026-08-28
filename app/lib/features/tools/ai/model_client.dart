import 'dart:convert';

import 'package:http/http.dart' as http;

abstract interface class ModelClient {
  Future<String> complete(List<Map<String, String>> messages);
}

class OpenAiCompatibleClient implements ModelClient {
  OpenAiCompatibleClient({
    required this.endpoint,
    required this.model,
    this.apiKey = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String endpoint;
  final String model;
  final String apiKey;
  final http.Client _http;

  static String chatCompletionsUrl(String endpoint) {
    var base = endpoint.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) return base;
    if (base.endsWith('/v1')) return '$base/chat/completions';
    return '$base/v1/chat/completions';
  }

  @override
  Future<String> complete(List<Map<String, String>> messages) async {
    final uri = Uri.parse(chatCompletionsUrl(endpoint));
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.2,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('模型接口返回 ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('模型接口返回了无法解析的内容');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('模型接口没有返回内容');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('模型接口没有返回文本');
    }
    return content.trim();
  }
}

class RecordingModelClient implements ModelClient {
  RecordingModelClient({this.reply = '示例回复', this.onComplete});

  final String reply;
  final void Function(List<Map<String, String>> messages)? onComplete;
  int calls = 0;
  List<Map<String, String>>? lastMessages;

  @override
  Future<String> complete(List<Map<String, String>> messages) async {
    calls += 1;
    lastMessages = messages;
    onComplete?.call(messages);
    return reply;
  }
}
