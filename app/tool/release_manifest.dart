import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const releaseManifestSchemaVersion = 1;

class ReleaseManifestAsset {
  const ReleaseManifestAsset({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String path;
  final int bytes;
  final String sha256;

  Map<String, Object> toJson() => {
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
  };
}

class ReleaseManifest {
  const ReleaseManifest({
    required this.version,
    required this.commit,
    required this.generatedAt,
    required this.assets,
  });

  final String version;
  final String commit;
  final DateTime generatedAt;
  final List<ReleaseManifestAsset> assets;

  Map<String, Object> toJson() => {
    'schema_version': releaseManifestSchemaVersion,
    'product': 'universal-reader',
    'version': version,
    'commit': commit,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'assets': [for (final asset in assets) asset.toJson()],
  };

  String toSha256Sums() {
    return '${[for (final asset in assets) '${asset.sha256}  ${asset.path}'].join('\n')}\n';
  }
}

ReleaseManifest buildReleaseManifest({
  required Directory artifacts,
  required String version,
  required String commit,
  DateTime? generatedAt,
}) {
  final files = artifacts.listSync(recursive: true).whereType<File>().where((
    file,
  ) {
    final normalized = file.path.replaceAll('\\', '/');
    return !normalized.endsWith('/release-manifest.json') &&
        !normalized.endsWith('/SHA256SUMS');
  }).toList()..sort((left, right) => left.path.compareTo(right.path));
  final assets = <ReleaseManifestAsset>[];
  for (final file in files) {
    final bytes = file.readAsBytesSync();
    assets.add(
      ReleaseManifestAsset(
        path: _relativePath(artifacts.path, file.path),
        bytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    );
  }
  return ReleaseManifest(
    version: version,
    commit: commit,
    generatedAt: generatedAt ?? DateTime.now(),
    assets: assets,
  );
}

void main(List<String> arguments) {
  try {
    final options = _parseOptions(arguments);
    final manifest = buildReleaseManifest(
      artifacts: Directory(options.artifacts),
      version: options.version,
      commit: options.commit,
    );
    final output = Directory(options.output);
    output.createSync(recursive: true);
    File('${output.path}/release-manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
    );
    File('${output.path}/SHA256SUMS')
        .writeAsStringSync(manifest.toSha256Sums());
    print(
      'Release manifest generated: ${manifest.assets.length} assets '
      'for ${manifest.version}',
    );
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  }
}

class _ManifestOptions {
  const _ManifestOptions({
    required this.artifacts,
    required this.version,
    required this.commit,
    required this.output,
  });

  final String artifacts;
  final String version;
  final String commit;
  final String output;
}

_ManifestOptions _parseOptions(List<String> arguments) {
  String? artifacts;
  String? version;
  String? commit;
  String? output;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    String value() {
      if (index + 1 >= arguments.length) {
        throw FormatException('$argument requires a value.');
      }
      return arguments[++index];
    }

    switch (argument) {
      case '--artifacts':
        artifacts = value();
      case '--version':
        version = value();
      case '--commit':
        commit = value();
      case '--output':
        output = value();
      default:
        throw FormatException('Unknown argument: $argument');
    }
  }
  if (artifacts == null || version == null || commit == null) {
    throw const FormatException(
      '--artifacts, --version, and --commit are required.',
    );
  }
  return _ManifestOptions(
    artifacts: artifacts,
    version: version,
    commit: commit,
    output: output ?? artifacts,
  );
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
