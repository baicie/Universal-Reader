import 'dart:io';

class ReleaseVersions {
  const ReleaseVersions({
    required this.appVersion,
    required this.rustVersion,
    required this.lockedRustVersions,
  });

  final String appVersion;
  final String rustVersion;
  final List<String> lockedRustVersions;
}

void main(List<String> arguments) {
  try {
    final tag = _parseTag(arguments);
    final repositoryRoot = Directory.current.parent;
    final versions = inspectReleaseVersions(repositoryRoot);
    if (tag != null && tag != versions.appVersion) {
      throw FormatException(
        'Release tag $tag does not match app version ${versions.appVersion}.',
      );
    }
    final mismatch = versions.lockedRustVersions.where(
      (version) => version != versions.rustVersion,
    );
    if (mismatch.isNotEmpty) {
      throw FormatException(
        'Cargo.lock versions do not match ${versions.rustVersion}: '
        '${mismatch.join(', ')}',
      );
    }
    final changelog = File('${repositoryRoot.path}/CHANGELOG.md')
        .readAsStringSync();
    if (!changelog.contains('## ${versions.appVersion} - ')) {
      throw FormatException(
        'CHANGELOG.md has no section for ${versions.appVersion}.',
      );
    }
    print(
      'Release versions verified: '
      'app=${versions.appVersion} rust=${versions.rustVersion} '
      'lock=${versions.lockedRustVersions.join(',')}',
    );
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  }
}

ReleaseVersions inspectReleaseVersions(Directory repositoryRoot) {
  final appVersion = appVersionFromPubspec(
    File('${repositoryRoot.path}/app/pubspec.yaml').readAsStringSync(),
  );
  final rustVersion = rustWorkspaceVersionFromCargoToml(
    File('${repositoryRoot.path}/rust/Cargo.toml').readAsStringSync(),
  );
  final lockedRustVersions = lockedRustVersionsFromCargoLock(
    File('${repositoryRoot.path}/rust/Cargo.lock').readAsStringSync(),
  );
  if (lockedRustVersions.isEmpty) {
    throw const FormatException('No universal-reader packages in Cargo.lock.');
  }
  return ReleaseVersions(
    appVersion: appVersion,
    rustVersion: rustVersion,
    lockedRustVersions: lockedRustVersions,
  );
}

String appVersionFromPubspec(String source) {
  final match = RegExp(
    r'^version:\s*([^+\s]+)(?:\+\d+)?\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    throw const FormatException('app/pubspec.yaml has no version.');
  }
  return match.group(1)!;
}

String rustWorkspaceVersionFromCargoToml(String source) {
  final section = _tomlSection(source, 'workspace.package');
  final match = RegExp(
    r'^version\s*=\s*"([^"]+)"\s*$',
    multiLine: true,
  ).firstMatch(section);
  if (match == null) {
    throw const FormatException('rust/Cargo.toml has no workspace version.');
  }
  return match.group(1)!;
}

List<String> lockedRustVersionsFromCargoLock(String source) {
  final versions = <String>[];
  final blocks = source.split('[[package]]');
  for (final block in blocks.skip(1)) {
    final name = RegExp(
      r'^name\s*=\s*"([^"]+)"',
      multiLine: true,
    ).firstMatch(block)?.group(1);
    if (name == null || !name.startsWith('universal-reader-')) continue;
    final version = RegExp(
      r'^version\s*=\s*"([^"]+)"',
      multiLine: true,
    ).firstMatch(block)?.group(1);
    if (version == null) {
      throw FormatException('Cargo.lock package $name has no version.');
    }
    versions.add(version);
  }
  versions.sort();
  return versions;
}

String? _parseTag(List<String> arguments) {
  String? tag;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--tag') {
      if (index + 1 >= arguments.length) {
        throw const FormatException('--tag requires a value.');
      }
      tag = arguments[++index];
    } else if (argument.startsWith('--tag=')) {
      tag = argument.substring('--tag='.length);
    } else {
      throw FormatException('Unknown argument: $argument');
    }
  }
  if (tag == null || tag.isEmpty) return null;
  return tag.startsWith('v') ? tag.substring(1) : tag;
}

String _tomlSection(String source, String name) {
  final start = source.indexOf('[$name]');
  if (start < 0) throw FormatException('Missing [$name] in Cargo.toml.');
  final rest = source.substring(start + name.length + 2);
  final next = RegExp(r'^\[', multiLine: true).firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}
