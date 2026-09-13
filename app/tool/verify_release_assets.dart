import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _manifestName = 'release-manifest.json';
const _sumsName = 'SHA256SUMS';

void main(List<String> arguments) {
  try {
    final options = _parseOptions(arguments);
    final result = verifyReleaseAssets(
      Directory(options.directory),
      expectedVersion: options.version,
      expectedCommit: options.commit,
    );
    print(
      'Release assets verified: ${result.assetCount} files, '
      'version ${result.version}, commit ${result.commit}',
    );
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  }
}

class ReleaseVerificationResult {
  const ReleaseVerificationResult({
    required this.version,
    required this.commit,
    required this.assetCount,
  });

  final String version;
  final String commit;
  final int assetCount;
}

ReleaseVerificationResult verifyReleaseAssets(
  Directory directory, {
  String? expectedVersion,
  String? expectedCommit,
}) {
  final manifestFile = File('${directory.path}/$_manifestName');
  if (!manifestFile.existsSync()) {
    throw const FormatException('release-manifest.json is missing.');
  }
  final decoded = jsonDecode(manifestFile.readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('release-manifest.json is malformed.');
  }
  final version = decoded['version'];
  final commit = decoded['commit'];
  final rawAssets = decoded['assets'];
  if (decoded['schema_version'] != 1 ||
      decoded['product'] != 'universal-reader' ||
      version is! String ||
      commit is! String ||
      rawAssets is! List) {
    throw const FormatException('release-manifest.json has invalid fields.');
  }
  if (expectedVersion != null && expectedVersion != version) {
    throw FormatException(
      'Manifest version $version does not match $expectedVersion.',
    );
  }
  if (expectedCommit != null && expectedCommit != commit) {
    throw FormatException(
      'Manifest commit $commit does not match $expectedCommit.',
    );
  }

  final expectedSums = <String, String>{};
  for (final raw in rawAssets) {
    if (raw is! Map) {
      throw const FormatException('Manifest asset is malformed.');
    }
    final path = raw['path'];
    final bytes = raw['bytes'];
    final digest = raw['sha256'];
    if (path is! String ||
        path.isEmpty ||
        path.contains('..') ||
        path.startsWith('/') ||
        bytes is! int ||
        digest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw const FormatException('Manifest asset fields are invalid.');
    }
    if (expectedSums.containsKey(path)) {
      throw FormatException('Duplicate manifest asset: $path');
    }
    final file = File('${directory.path}/$path');
    if (!file.existsSync()) {
      throw FormatException('Manifest asset is missing: $path');
    }
    final content = file.readAsBytesSync();
    if (content.length != bytes) {
      throw FormatException(
        'Size mismatch for $path: ${content.length} != $bytes',
      );
    }
    final actual = sha256.convert(content).toString();
    if (actual != digest) {
      throw FormatException('SHA-256 mismatch for $path.');
    }
    expectedSums[path] = digest;
  }

  final sumsFile = File('${directory.path}/$_sumsName');
  if (!sumsFile.existsSync()) {
    throw const FormatException('SHA256SUMS is missing.');
  }
  final parsedSums = <String, String>{};
  for (final line in sumsFile.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final match = RegExp(r'^([0-9a-f]{64})  (.+)$').firstMatch(line);
    if (match == null) {
      throw FormatException('Malformed SHA256SUMS line: $line');
    }
    parsedSums[match.group(2)!] = match.group(1)!;
  }
  if (!_sameMap(expectedSums, parsedSums)) {
    throw const FormatException('SHA256SUMS does not match the manifest.');
  }

  final actualFiles = directory
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => _relativePath(directory.path, file.path))
      .where((name) => name != _manifestName && name != _sumsName)
      .toSet();
  if (!_sameSet(expectedSums.keys.toSet(), actualFiles)) {
    throw const FormatException(
      'Artifact directory contains unlisted or missing files.',
    );
  }

  return ReleaseVerificationResult(
    version: version,
    commit: commit,
    assetCount: expectedSums.length,
  );
}

class _VerificationOptions {
  const _VerificationOptions({
    required this.directory,
    this.version,
    this.commit,
  });

  final String directory;
  final String? version;
  final String? commit;
}

_VerificationOptions _parseOptions(List<String> arguments) {
  String? directory;
  String? version;
  String? commit;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    String value() {
      if (index + 1 >= arguments.length) {
        throw FormatException('$argument requires a value.');
      }
      return arguments[++index];
    }

    switch (argument) {
      case '--directory':
        directory = value();
      case '--version':
        version = value();
      case '--commit':
        commit = value();
      default:
        throw FormatException('Unknown argument: $argument');
    }
  }
  if (directory == null) {
    throw const FormatException('--directory is required.');
  }
  return _VerificationOptions(
    directory: directory,
    version: version,
    commit: commit,
  );
}

bool _sameMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

bool _sameSet(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

String _relativePath(String root, String path) {
  final normalizedRoot = root
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'/$'), '');
  final normalizedPath = path.replaceAll('\\', '/');
  return normalizedPath.substring(
    normalizedPath.startsWith('$normalizedRoot/')
        ? normalizedRoot.length + 1
        : 0,
  );
}
