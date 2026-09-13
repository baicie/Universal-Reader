import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/extract_changelog_section.dart';

void main() {
  const changelog = '''# Changelog

## 0.0.1-dev.12 - 2026-08-31

### Test Coverage Improvements
- dev.12 had something we want to drop.

### Documentation
- dev.12 doc line.

## 0.0.1-dev.13 - 2026-09-13

- dev.13 reader settings.
- Imported GBK/GB18030 TXT decoding as Chinese.

### Test Coverage Improvements
- Closed remaining coverage gaps.

## Unreleased

- Will land in dev.14.
''';

  group('extractChangelogSection', () {
    test('returns the whole section for a released version', () {
      final section = extractChangelogSection(changelog, '0.0.1-dev.13');
      expect(section, startsWith('## 0.0.1-dev.13 - 2026-09-13'));
      expect(section, contains('dev.13 reader settings'));
      expect(section, contains('Closed remaining coverage gaps'));
      expect(section, isNot(contains('Will land in dev.14')));
      expect(section, isNot(contains('dev.12 had something')));
    });

    test('returns the whole section for an earlier version', () {
      final section = extractChangelogSection(changelog, '0.0.1-dev.12');
      expect(section, startsWith('## 0.0.1-dev.12 - 2026-08-31'));
      expect(section, contains('dev.12 had something we want to drop'));
      expect(section, isNot(contains('dev.13 reader settings')));
    });

    test('returns Unreleased section when requested explicitly', () {
      final section = extractChangelogSection(
        changelog,
        'Unreleased',
        includeUnreleased: true,
      );
      expect(section, startsWith('## Unreleased'));
      expect(section, contains('Will land in dev.14'));
    });

    test('refuses Unreleased by default', () {
      expect(
        () => extractChangelogSection(changelog, 'Unreleased'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on an unknown version', () {
      expect(
        () => extractChangelogSection(changelog, '9.9.9'),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts a tag form with the leading v', () {
      final section = extractChangelogSection(changelog, 'v0.0.1-dev.13');
      expect(section, startsWith('## 0.0.1-dev.13 - 2026-09-13'));
    });

    test('returns an empty body for a section with no bullets', () {
      final bare = '''# Changelog

## 0.0.1-dev.13 - 2026-09-13

## Unreleased
''';
      final section = extractChangelogSection(bare, '0.0.1-dev.13');
      expect(section, '## 0.0.1-dev.13 - 2026-09-13\n');
    });

    test('ignores ## subsections inside the version section', () {
      final section = extractChangelogSection(changelog, '0.0.1-dev.13');
      expect(section, contains('### Test Coverage Improvements'));
      expect(section, contains('Closed remaining coverage gaps'));
    });
  });

  group('extractChangelogSectionFromFile', () {
    test('reads the configured changelog file', () {
      final tempDir = Directory.systemTemp.createTempSync('changelog_');
      final tempFile = File('${tempDir.path}/CHANGELOG.md');
      tempFile.writeAsStringSync(changelog);
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final section = extractChangelogSectionFromFile(
        tempFile.path,
        '0.0.1-dev.13',
      );
      expect(section, startsWith('## 0.0.1-dev.13 - 2026-09-13'));
    });

    test('surfaces a missing file as an IOException', () {
      expect(
        () => extractChangelogSectionFromFile(
          'does/not/exist/CHANGELOG.md',
          '0.0.1-dev.13',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
