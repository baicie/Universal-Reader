import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manifest.dart';

void main() {
  test('release manifest records sorted asset hashes and sizes', () {
    final directory = Directory.systemTemp.createTempSync('ur-manifest-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/b.txt').writeAsStringSync('second');
    File('${directory.path}/a.txt').writeAsStringSync('first');
    File('${directory.path}/SHA256SUMS').writeAsStringSync('old');

    final manifest = buildReleaseManifest(
      artifacts: directory,
      version: '1.0.0-rc.1',
      commit: 'abc123',
      generatedAt: DateTime.utc(2026, 9, 14),
    );

    expect(manifest.assets.map((asset) => asset.path), ['a.txt', 'b.txt']);
    expect(manifest.assets.first.bytes, 5);
    expect(manifest.toJson()['schema_version'], releaseManifestSchemaVersion);
    expect(manifest.toSha256Sums(), contains('  a.txt\n'));
    expect(manifest.toSha256Sums(), isNot(contains('SHA256SUMS')));
  });

  test('release manifest JSON is stable', () {
    final directory = Directory.systemTemp.createTempSync('ur-manifest-json-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/asset').writeAsStringSync('x');
    final manifest = buildReleaseManifest(
      artifacts: directory,
      version: '1.0.0-rc.1',
      commit: 'abc123',
      generatedAt: DateTime.utc(2026, 9, 14),
    );

    final decoded = jsonDecode(jsonEncode(manifest.toJson()));
    expect(decoded['product'], 'universal-reader');
    expect(decoded['version'], '1.0.0-rc.1');
    expect(decoded['commit'], 'abc123');
    expect(decoded['assets'], hasLength(1));
  });
}
