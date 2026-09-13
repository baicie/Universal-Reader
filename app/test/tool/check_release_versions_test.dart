import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release_versions.dart';

void main() {
  test('parses Flutter version without the build suffix', () {
    expect(appVersionFromPubspec('version: 1.2.3-rc.1+42\n'), '1.2.3-rc.1');
  });

  test('parses the Rust workspace version', () {
    expect(
      rustWorkspaceVersionFromCargoToml('''
[workspace.package]
version = "1.2.3-rc.1"
edition = "2024"
'''),
      '1.2.3-rc.1',
    );
  });

  test('collects only universal-reader lock versions', () {
    expect(
      lockedRustVersionsFromCargoLock('''
[[package]]
name = "serde"
version = "9.9.9"

[[package]]
name = "universal-reader-server"
version = "1.2.3-rc.1"
'''),
      ['1.2.3-rc.1'],
    );
  });

  test('repository release candidate versions are frozen', () {
    final versions = inspectReleaseVersions(Directory.current.parent);
    expect(versions.appVersion, '1.0.0-rc.1');
    expect(versions.rustVersion, '1.0.0-rc.1');
    expect(versions.lockedRustVersions, everyElement('1.0.0-rc.1'));
  });
}
