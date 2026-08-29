import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const maxAnnotations = 100;

class ReaderAnnotation {
  const ReaderAnnotation({
    required this.id,
    required this.note,
    this.quote = '',
    this.locatorLabel = '',
    this.source = 'assistant',
    required this.createdAt,
  });

  final String id;
  final String note;
  final String quote;
  final String locatorLabel;
  final String source;
  final DateTime createdAt;

  Map<String, dynamic> toServiceJson() => {
    'id': id,
    'note': note,
    'quote': quote,
    'locator_label': locatorLabel,
    'source': source,
    'created_at_ms': createdAt.toUtc().millisecondsSinceEpoch,
  };

  factory ReaderAnnotation.fromJson(Map<String, dynamic> json) {
    final createdAtMs =
        (json['createdAtMs'] as num?)?.toInt() ??
        (json['created_at_ms'] as num?)?.toInt() ??
        0;
    return ReaderAnnotation(
      id: json['id'] as String? ?? '',
      note: json['note'] as String? ?? '',
      quote: json['quote'] as String? ?? '',
      locatorLabel:
          json['locatorLabel'] as String? ??
          json['locator_label'] as String? ??
          '',
      source: json['source'] as String? ?? 'assistant',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    );
  }
}

List<ReaderAnnotation> parseAnnotations(Object? decoded) {
  if (decoded is! List) {
    throw const FormatException('corrupt annotations');
  }
  return [
    for (final item in decoded)
      ReaderAnnotation.fromJson(
        item is Map
            ? Map<String, dynamic>.from(item)
            : throw const FormatException('corrupt annotations'),
      ),
  ];
}

List<ReaderAnnotation> trimAnnotations(List<ReaderAnnotation> notes) {
  if (notes.length <= maxAnnotations) return List.of(notes);
  return notes.sublist(notes.length - maxAnnotations);
}

abstract interface class AnnotationRepository {
  Future<List<ReaderAnnotation>> load(String documentId);
  Future<void> save(String documentId, List<ReaderAnnotation> notes);
}

extension AnnotationRepositoryWrite on AnnotationRepository {
  Future<List<ReaderAnnotation>> append(
    String documentId,
    ReaderAnnotation note,
  ) async {
    final next = trimAnnotations([...await load(documentId), note]);
    await save(documentId, next);
    return next;
  }
}

class SharedPreferencesAnnotationRepository implements AnnotationRepository {
  SharedPreferencesAnnotationRepository(this.preferences);

  static const prefix = 'universal_reader.annotations.v1.';
  final SharedPreferences preferences;

  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    final raw = preferences.getString('$prefix$documentId');
    if (raw == null || raw.isEmpty) return const [];
    return parseAnnotations(jsonDecode(raw));
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    await preferences.setString(
      '$prefix$documentId',
      jsonEncode(
        trimAnnotations(notes).map((note) => note.toServiceJson()).toList(),
      ),
    );
  }
}

class InMemoryAnnotationRepository implements AnnotationRepository {
  final Map<String, List<ReaderAnnotation>> _notes = {};

  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    return List.of(_notes[documentId] ?? const []);
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    _notes[documentId] = trimAnnotations(notes);
  }
}

class HttpAnnotationRepository implements AnnotationRepository {
  HttpAnnotationRepository({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri _uri(String documentId) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root/v1/library/documents/$documentId/annotations');
  }

  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    final response = await _http.get(_uri(documentId));
    if (response.statusCode != 200) {
      throw FormatException('无法读取笔记 (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['notes'] != null) {
      return parseAnnotations(decoded['notes']);
    }
    return parseAnnotations(decoded);
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    final response = await _http.put(
      _uri(documentId),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'notes': trimAnnotations(notes)
            .map((note) => note.toServiceJson())
            .toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw FormatException('无法保存笔记 (${response.statusCode})');
    }
  }
}
