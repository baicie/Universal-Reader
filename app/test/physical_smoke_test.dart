import 'package:flutter_test/flutter_test.dart';

import '../tool/physical_smoke.dart';

void main() {
  const android = FlutterDevice(
    name: 'Pixel',
    id: 'SERIAL',
    targetPlatform: 'android-arm64',
    emulator: false,
    sdk: 'Android 16',
  );
  const androidEmulator = FlutterDevice(
    name: 'Android SDK built for x86_64',
    id: 'emulator-5554',
    targetPlatform: 'android-x64',
    emulator: true,
    sdk: 'Android 14',
  );
  const iphone = FlutterDevice(
    name: 'iPhone',
    id: 'UDID',
    targetPlatform: 'ios',
    emulator: false,
    sdk: 'iOS 19',
  );

  test('parses flutter devices JSON', () {
    final devices = parseFlutterDevices(
      '[{"name":"Pixel","id":"SERIAL","targetPlatform":"android-arm64",'
      '"emulator":false,"sdk":"Android 16"}]',
    );

    expect(devices, hasLength(1));
    expect(devices.single.id, 'SERIAL');
  });

  test('selects the requested physical device', () {
    final device = selectPhysicalDevice(
      const [android, androidEmulator],
      platform: 'android',
      requestedId: 'SERIAL',
    );

    expect(device, same(android));
  });

  test('rejects an emulator-only selection', () {
    expect(
      () => selectPhysicalDevice(const [androidEmulator], platform: 'android'),
      throwsA(isA<PhysicalSmokeException>()),
    );
  });

  test('requires a device id when multiple physical devices exist', () {
    expect(
      () => selectPhysicalDevice(const [
        android,
        FlutterDevice(
          name: 'Second Pixel',
          id: 'SECOND',
          targetPlatform: 'android-arm64',
          emulator: false,
          sdk: 'Android 16',
        ),
      ], platform: 'android'),
      throwsA(isA<PhysicalSmokeException>()),
    );
  });

  test('parses physical smoke options', () {
    final options = PhysicalSmokeOptions.parse(const [
      '--platform=android',
      '--device-id=SERIAL',
      '--release-artifact=app-release.apk',
      '--report=report.md',
    ]);

    expect(options.platform, 'android');
    expect(options.deviceId, 'SERIAL');
    expect(options.releaseArtifact, 'app-release.apk');
    expect(options.reportPath, 'report.md');
  });

  test('renders a passing physical smoke report', () {
    final report = renderPhysicalSmokeReport(
      options: const PhysicalSmokeOptions(
        platform: 'ios',
        reportPath: 'report.md',
      ),
      device: iphone,
      nativeArtifact: '/native/libuniversal_reader_native.a',
      conversion: const CommandOutcome(
        command: 'flutter test',
        exitCode: 0,
        output: 'All tests passed!',
      ),
      completedAt: DateTime.utc(2026, 9, 13),
    );

    expect(report, contains('- Device: iPhone'));
    expect(report, contains('- Conversion result: PASS'));
    expect(report, contains('PASS'));
    expect(report, contains('All tests passed!'));
  });
}
