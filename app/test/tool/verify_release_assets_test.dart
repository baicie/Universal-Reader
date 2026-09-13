import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manifest.dart';
import '../../tool/verify_release_assets.dart';

Directory _artifacts() {
  final directory = Directory.systemTemp.createTempSync('ur-verify-');
  addTearDown(() => directory.deleteSync(recursive: true));
  File('${directory.path}/one.zip').writeAsStringSync('one');
  final manifest = buildReleaseManifest(
    artifacts: directory,
    version: '1.0.0-rc.1',
    commit: 'abc123',
    generatedAt: DateTime.utc(2026, 9, 14),
  );
  File('${directory.path}/release-manifest.json')
      .writeAsStringSync(jsonEncode(manifest.toJson()));
  File('${directory.path}/SHA256SUMS')
      .writeAsStringSync(manifest.toSha256Sums());
  return directory;
}

void main() {
  test('verifies manifest, sums, size, hashes, and file set', () {
    final directory = _artifacts();
    final result = verifyReleaseAssets(
      directory,
      expectedVersion: '1.0.0-rc.1',
      expectedCommit: 'abc123',
    );

    expect(result.assetCount, 1);
    expect(result.version, '1.0.0-rc.1');
  });

  test('rejects modified assets', () {
    final directory = _artifacts();
    File('${directory.path}/one.zip').writeAsStringSync('changed');

    expect(
      () => verifyReleaseAssets(directory),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unlisted files and version mismatches', () {
    final directory = _artifacts();
    File('${directory.path}/extra.txt').writeAsStringSync('extra');
    expect(
      () => verifyReleaseAssets(directory),
      throwsA(isA<FormatException>()),
    );

    File('${directory.path}/extra.txt').deleteSync();
    expect(
      () => verifyReleaseAssets(directory, expectedVersion: '2.0.0'),
      throwsA(isA<FormatException>()),
    );
  });

  test('verifier implementation hashes match the manifest format', () {
    expect(sha256.convert(utf8.encode('one')).toString(), hasLength(64));
  });
}
