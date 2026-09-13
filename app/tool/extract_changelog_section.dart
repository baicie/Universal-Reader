import 'dart:io';

/// Extracts the section for a given version from the project CHANGELOG.
///
/// `changelog` is the full text of the file. The function returns the section
/// header (`## <version>`) followed by every line up to (but not including)
/// the next `## ` header. Lines that use `### ` are kept because they belong
/// to the same version.
///
/// `version` is matched against the markdown header text. A leading `v` is
/// stripped so that release tags like `v0.0.1-dev.13` resolve to the
/// `0.0.1-dev.13` section.
///
/// `includeUnreleased` must be true for `Unreleased` to be returned; otherwise
/// the missing placeholder is rejected so a release never ships with the
/// developer's draft notes by mistake.
String extractChangelogSection(
  String changelog,
  String version, {
  bool includeUnreleased = false,
}) {
  final normalizedTarget = _normalize(version);
  if (normalizedTarget == 'Unreleased' && !includeUnreleased) {
    throw FormatException(
      'Refusing to ship the Unreleased placeholder; pass '
      '--include-unreleased to override.',
    );
  }

  final lines = changelog.split('\n');
  final headerRegex = RegExp(r'^## (?<version>[^\s]+)(?: - .*)?\s*$');
  int? startIndex;
  int? nextHeaderIndex;
  for (var i = 0; i < lines.length; i++) {
    final match = headerRegex.firstMatch(lines[i]);
    if (match == null) continue;
    final name = _normalize(match.namedGroup('version')!);
    if (startIndex == null) {
      if (name == normalizedTarget) {
        startIndex = i;
      }
    } else {
      nextHeaderIndex = i;
      break;
    }
  }

  if (startIndex == null) {
    throw FormatException('No "## $version" section found in CHANGELOG.');
  }

  final endIndex = nextHeaderIndex ?? lines.length;
  return lines.sublist(startIndex, endIndex).join('\n');
}

/// Convenience wrapper that reads the changelog from disk and runs
/// [extractChangelogSection] on its contents. A missing file surfaces as a
/// [FileSystemException] so the CLI prints a useful diagnostic.
String extractChangelogSectionFromFile(
  String path,
  String version, {
  bool includeUnreleased = false,
}) {
  final file = File(path);
  final contents = file.readAsStringSync();
  return extractChangelogSection(
    contents,
    version,
    includeUnreleased: includeUnreleased,
  );
}

String _normalize(String name) {
  var value = name.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  return value;
}

/// CLI entry point. Usage:
///   dart run tool/extract_changelog_section.dart <version>
///   [--file <path>] [--include-unreleased]
///
/// Writes the requested section to stdout and exits non-zero on error.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/extract_changelog_section.dart <version> '
      '[--file <path>] [--include-unreleased]',
    );
    exit(64);
  }

  final parsed = _parseArgs(args);
  try {
    final section = extractChangelogSectionFromFile(
      parsed.file,
      parsed.version,
      includeUnreleased: parsed.includeUnreleased,
    );
    stdout.write(section);
    if (!section.endsWith('\n')) {
      stdout.writeln();
    }
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exit(1);
  } on FileSystemException catch (error) {
    stderr.writeln('Error reading ${parsed.file}: ${error.message}');
    exit(1);
  }
}

class _CliOptions {
  const _CliOptions({
    required this.version,
    required this.file,
    required this.includeUnreleased,
  });

  final String version;
  final String file;
  final bool includeUnreleased;
}

_CliOptions _parseArgs(List<String> args) {
  var version = args.first;
  var file = 'CHANGELOG.md';
  var includeUnreleased = false;
  for (var i = 1; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--include-unreleased') {
      includeUnreleased = true;
    } else if (arg == '--file') {
      if (i + 1 >= args.length) {
        stderr.writeln('--file requires a path argument.');
        exit(64);
      }
      file = args[i + 1];
      i++;
    } else {
      stderr.writeln('Unknown argument: $arg');
      exit(64);
    }
  }
  return _CliOptions(
    version: version,
    file: file,
    includeUnreleased: includeUnreleased,
  );
}
