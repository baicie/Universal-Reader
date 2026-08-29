import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../reader_tool.dart';

const maxConversationTurns = 50;

class ConversationTurn {
  const ConversationTurn({
    required this.kind,
    required this.reply,
    this.question = '',
    this.locatorLabel = '',
    required this.createdAt,
  });

  final ReaderToolKind kind;
  final String question;
  final String reply;
  final String locatorLabel;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => toServiceJson();

  Map<String, dynamic> toServiceJson() => {
    'kind': kind.name,
    'question': question,
    'reply': reply,
    'locator_label': locatorLabel,
    'created_at_ms': createdAt.toUtc().millisecondsSinceEpoch,
  };

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? '';
    final kind = ReaderToolKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => ReaderToolKind.ask,
    );
    final createdAtMs =
        (json['createdAtMs'] as num?)?.toInt() ??
        (json['created_at_ms'] as num?)?.toInt() ??
        0;
    return ConversationTurn(
      kind: kind,
      question: json['question'] as String? ?? '',
      reply: json['reply'] as String? ?? '',
      locatorLabel:
          json['locatorLabel'] as String? ??
          json['locator_label'] as String? ??
          '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    );
  }
}

List<ConversationTurn> parseConversationTurns(Object? decoded) {
  if (decoded is! List) {
    throw const FormatException('corrupt conversation');
  }
  return [
    for (final item in decoded)
      ConversationTurn.fromJson(
        item is Map
            ? Map<String, dynamic>.from(item)
            : throw const FormatException('corrupt conversation'),
      ),
  ];
}

List<ConversationTurn> trimConversation(List<ConversationTurn> turns) {
  if (turns.length <= maxConversationTurns) return List.of(turns);
  return turns.sublist(turns.length - maxConversationTurns);
}

abstract interface class ConversationRepository {
  Future<List<ConversationTurn>> load(String documentId);
  Future<void> save(String documentId, List<ConversationTurn> turns);
}

extension ConversationRepositoryAppend on ConversationRepository {
  Future<List<ConversationTurn>> append(
    String documentId,
    ConversationTurn turn,
  ) async {
    final next = trimConversation([...await load(documentId), turn]);
    await save(documentId, next);
    return next;
  }
}

class InMemoryConversationRepository implements ConversationRepository {
  InMemoryConversationRepository([
    Map<String, List<ConversationTurn>> initial = const {},
  ]) : _turns = {
         for (final entry in initial.entries) entry.key: List.of(entry.value),
       };

  final Map<String, List<ConversationTurn>> _turns;

  @override
  Future<List<ConversationTurn>> load(String documentId) async {
    return List.of(_turns[documentId] ?? const []);
  }

  @override
  Future<void> save(String documentId, List<ConversationTurn> turns) async {
    _turns[documentId] = trimConversation(turns);
  }
}

class SharedPreferencesConversationRepository
    implements ConversationRepository {
  SharedPreferencesConversationRepository(this.preferences);

  static const storagePrefix = 'universal_reader.conversation.v1.';
  final SharedPreferences preferences;

  @override
  Future<List<ConversationTurn>> load(String documentId) async {
    final raw = preferences.getString('$storagePrefix$documentId');
    if (raw == null || raw.isEmpty) return const [];
    return parseConversationTurns(jsonDecode(raw));
  }

  @override
  Future<void> save(String documentId, List<ConversationTurn> turns) async {
    final payload = trimConversation(turns)
        .map((turn) => turn.toJson())
        .toList();
    await preferences.setString(
      '$storagePrefix$documentId',
      jsonEncode(payload),
    );
  }
}

class HttpConversationRepository implements ConversationRepository {
  HttpConversationRepository({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri _uri(String documentId) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$root/v1/library/documents/${Uri.encodeComponent(documentId)}/conversations',
    );
  }

  @override
  Future<List<ConversationTurn>> load(String documentId) async {
    final response = await _http.get(_uri(documentId));
    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) {
      throw FormatException(
        'conversation request failed (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('corrupt conversation');
    }
    return parseConversationTurns(decoded['turns']);
  }

  @override
  Future<void> save(String documentId, List<ConversationTurn> turns) async {
    final payload = trimConversation(turns);
    final response = await _http.put(
      _uri(documentId),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'turns': [for (final turn in payload) turn.toServiceJson()],
      }),
    );
    if (response.statusCode != 200) {
      throw FormatException(
        'conversation request failed (${response.statusCode})',
      );
    }
  }
}
