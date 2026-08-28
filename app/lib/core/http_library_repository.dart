import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'library_repository.dart';
import 'models.dart';

String libraryBaseUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null') return origin;
  }
  return 'http://127.0.0.1:8787';
}

Future<LibraryRepository> resolveLibraryRepository(
  SharedPreferences preferences, {
  http.Client? httpClient,
  String? baseUrl,
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  final origin = baseUrl ?? libraryBaseUrl();
  final client = httpClient ?? http.Client();
  try {
    final response = await client
        .get(Uri.parse('$origin/health'))
        .timeout(timeout);
    if (response.statusCode == 200 &&
        response.body.contains('universal-reader-server')) {
      return HttpLibraryRepository(baseUrl: origin, httpClient: client);
    }
  } catch (_) {}
  return SharedPreferencesLibraryRepository(preferences);
}

class HttpLibraryRepository implements LibraryRepository {
  HttpLibraryRepository({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  @override
  bool get usesRemoteStore => true;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  @override
  Future<List<LibraryDocument>> load() async {
    final response = await _http.get(_uri('/v1/library/documents'));
    if (response.statusCode != 200) {
      throw FormatException('无法读取书库 (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final documents = decoded['documents'];
    if (documents is! List) return [];
    return documents
        .whereType<Map>()
        .map(
          (item) => LibraryDocumentCodec.fromServiceJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  @override
  Future<void> save(List<LibraryDocument> documents) async {}

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    final request = http.MultipartRequest('POST', _uri('/v1/library/files'));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 415) {
      throw const FormatException('unsupported document format');
    }
    if (response.statusCode != 201) {
      throw FormatException('导入失败 (${response.statusCode})');
    }
    return LibraryDocumentCodec.fromServiceJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {
    final response = await _http.patch(
      _uri('/v1/library/documents/$id'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'progress': progress,
        'last_opened_ms': lastOpened.toUtc().millisecondsSinceEpoch,
      }),
    );
    if (response.statusCode != 200) {
      throw FormatException('无法保存进度 (${response.statusCode})');
    }
  }
}
