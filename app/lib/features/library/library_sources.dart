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

Future<SourceImportResult> syncLibraryFolder(
  LibraryRepository repository,
  String path,
) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('folder sync needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri('/v1/library/folder/sync'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'path': path}),
  );
  if (response.statusCode != 200) {
    throw FormatException('文件夹同步失败 (${response.statusCode})');
  }
  return _parseSourceResult(response.body);
}

Future<SourceImportResult> importLibraryS3(
  LibraryRepository repository, {
  required String endpoint,
  required String region,
  required String bucket,
  required String prefix,
  required String accessKey,
  required String secretKey,
}) {
  return _postS3(
    repository,
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    prefix: prefix,
    accessKey: accessKey,
    secretKey: secretKey,
    path: '/v1/library/s3/import',
    errorLabel: 'S3 导入失败',
  );
}

Future<SourceImportResult> syncLibraryS3(
  LibraryRepository repository, {
  required String endpoint,
  required String region,
  required String bucket,
  required String prefix,
  required String accessKey,
  required String secretKey,
}) {
  return _postS3(
    repository,
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    prefix: prefix,
    accessKey: accessKey,
    secretKey: secretKey,
    path: '/v1/library/s3/sync',
    errorLabel: 'S3 同步失败',
  );
}

Future<SourceImportResult> _postS3(
  LibraryRepository repository, {
  required String endpoint,
  required String region,
  required String bucket,
  required String prefix,
  required String accessKey,
  required String secretKey,
  required String path,
  required String errorLabel,
}) async {
  if (repository is! HttpLibraryRepository) {
    throw const FormatException('s3 sync needs the local server');
  }
  final response = await repository.httpClient.post(
    repository.uri(path),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      if (endpoint.trim().isNotEmpty) 'endpoint': endpoint.trim(),
      if (region.trim().isNotEmpty) 'region': region.trim(),
      if (bucket.trim().isNotEmpty) 'bucket': bucket.trim(),
      if (prefix.trim().isNotEmpty) 'prefix': prefix.trim(),
      if (accessKey.trim().isNotEmpty) 'access_key': accessKey.trim(),
      if (secretKey.trim().isNotEmpty) 'secret_key': secretKey.trim(),
    }),
  );
  if (response.statusCode != 200) {
    throw FormatException('$errorLabel (${response.statusCode})');
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
