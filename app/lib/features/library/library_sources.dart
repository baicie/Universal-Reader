import 'dart:convert';

import '../../core/http_library_repository.dart';
import '../../core/library_controller.dart';
import '../../core/library_repository.dart';

class SourceImportResult {
  const SourceImportResult({
    required this.imported,
    required this.skipped,
    this.pushed = 0,
  });

  final int imported;
  final int skipped;
  final int pushed;
}

Future<SourceImportResult> scanLibraryFolder(
  LibraryRepository repository,
  String path,
) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('folder scan needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri('/v1/library/scan'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'path': path}),
  );
  if (response.statusCode != 200) {
    throw FormatException('扫描失败 (${response.statusCode})');
  }
  return _parseSourceResult(response.body);
}

Future<SourceImportResult> importLibraryWebDav(
  LibraryRepository repository, {
  required String baseUrl,
  String username = '',
  String password = '',
}) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('webdav import needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri('/v1/library/webdav/import'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': username,
      'password': password,
      if (baseUrl.trim().isNotEmpty) 'base_url': baseUrl.trim(),
    }),
  );
  if (response.statusCode != 200) {
    throw FormatException('WebDAV 导入失败 (${response.statusCode})');
  }
  return _parseSourceResult(response.body);
}

SourceImportResult _parseSourceResult(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('corrupt source import');
  }
  return SourceImportResult(
    imported: (decoded['imported'] as num?)?.toInt() ?? 0,
    skipped: (decoded['skipped'] as num?)?.toInt() ?? 0,
    pushed: (decoded['pushed'] as num?)?.toInt() ?? 0,
  );
}

Future<SourceImportResult> syncLibraryWebDav(
  LibraryRepository repository, {
  required String baseUrl,
  String username = '',
  String password = '',
}) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('webdav sync needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri('/v1/library/webdav/sync'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': username,
      'password': password,
      if (baseUrl.trim().isNotEmpty) 'base_url': baseUrl.trim(),
    }),
  );
  if (response.statusCode != 200) {
    throw FormatException('WebDAV 同步失败 (${response.statusCode})');
  }
  return _parseSourceResult(response.body);
}

Future<SourceImportResult> watchLibraryFolder(
  LibraryRepository repository,
  String path,
) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('folder watch needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri('/v1/library/watch'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'path': path}),
  );
  if (response.statusCode != 200) {
    throw FormatException('监视失败 (${response.statusCode})');
  }
  return _parseSourceResult(response.body);
}

Future<ImportOutcome> applySourceImport(
  PersistedLibraryController library,
  SourceImportResult result,
) async {
  if (result.imported <= 0) return const ImportOutcome.unsupported();
  await library.load();
  return ImportOutcome.imported(result.imported);
}
