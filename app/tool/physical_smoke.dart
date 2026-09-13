import 'dart:convert';
import 'dart:io';

const nativeSmokeTest =
    'integration_test/native_format_converter_smoke_test.dart';
const androidApplicationId = 'io.universalreader.app';
const iosBundleId = 'io.universalreader.app';

class PhysicalSmokeException implements Exception {
  const PhysicalSmokeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhysicalSmokeOptions {
  const PhysicalSmokeOptions({
    required this.platform,
    required this.reportPath,
    this.deviceId,
    this.releaseArtifact,
  });

  final String platform;
  final String reportPath;
  final String? deviceId;
  final String? releaseArtifact;

  static PhysicalSmokeOptions parse(
    List<String> arguments, {
    String? defaultReportPath,
  }) {
    String? platform;
    String? deviceId;
    String? reportPath;
    String? releaseArtifact;

    for (final argument in arguments) {
      if (argument.startsWith('--platform=')) {
        platform = argument.substring('--platform='.length);
      } else if (argument.startsWith('--device-id=')) {
        deviceId = argument.substring('--device-id='.length);
      } else if (argument.startsWith('--report=')) {
        reportPath = argument.substring('--report='.length);
      } else if (argument.startsWith('--release-artifact=')) {
        releaseArtifact = argument.substring('--release-artifact='.length);
      } else {
        throw PhysicalSmokeException('Unknown argument: $argument');
      }
    }

    if (platform != 'android' && platform != 'ios') {
      throw const PhysicalSmokeException(
        'Pass --platform=android or --platform=ios.',
      );
    }
    if (deviceId != null && deviceId.isEmpty) {
      throw const PhysicalSmokeException('--device-id must not be empty.');
    }
    if (releaseArtifact != null && releaseArtifact.isEmpty) {
      throw const PhysicalSmokeException(
        '--release-artifact must not be empty.',
      );
    }

    return PhysicalSmokeOptions(
      platform: platform!,
      deviceId: deviceId,
      reportPath:
          reportPath ??
          defaultReportPath ??
          'build/physical-smoke/$platform-'
              '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '')}'
              '.md',
      releaseArtifact: releaseArtifact,
    );
  }
}

class FlutterDevice {
  const FlutterDevice({
    required this.name,
    required this.id,
    required this.targetPlatform,
    required this.emulator,
    required this.sdk,
  });

  final String name;
  final String id;
  final String targetPlatform;
  final bool emulator;
  final String sdk;

  factory FlutterDevice.fromJson(Map<String, dynamic> json) {
    return FlutterDevice(
      name: json['name'] as String? ?? '',
      id: json['id'] as String? ?? '',
      targetPlatform: json['targetPlatform'] as String? ?? '',
      emulator: json['emulator'] as bool? ?? false,
      sdk: json['sdk'] as String? ?? '',
    );
  }

  bool supports(String platform) {
    if (platform == 'android') return targetPlatform.startsWith('android');
    if (platform == 'ios') return targetPlatform.startsWith('ios');
    return false;
  }
}

class CommandOutcome {
  const CommandOutcome({
    required this.command,
    required this.exitCode,
    required this.output,
  });

  final String command;
  final int exitCode;
  final String output;

  bool get succeeded => exitCode == 0;
}

List<FlutterDevice> parseFlutterDevices(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const PhysicalSmokeException(
      'flutter devices returned invalid JSON.',
    );
  }
  return decoded
      .whereType<Map>()
      .map((device) => FlutterDevice.fromJson(device.cast<String, dynamic>()))
      .toList(growable: false);
}

FlutterDevice selectPhysicalDevice(
  List<FlutterDevice> devices, {
  required String platform,
  String? requestedId,
}) {
  final matching = devices
      .where((device) => device.supports(platform))
      .toList();
  if (matching.isEmpty) {
    throw PhysicalSmokeException(
      'No $platform device was reported by flutter devices.',
    );
  }

  final physical = matching.where((device) => !device.emulator).toList();
  if (physical.isEmpty) {
    throw PhysicalSmokeException(
      'Only $platform emulators are connected; attach a physical device.',
    );
  }

  if (requestedId != null) {
    final exact = physical.where((device) => device.id == requestedId).toList();
    if (exact.isEmpty) {
      throw PhysicalSmokeException(
        'Physical $platform device "$requestedId" was not found. '
        'Available: ${physical.map((device) => device.id).join(', ')}',
      );
    }
    return exact.single;
  }

  if (physical.length != 1) {
    throw PhysicalSmokeException(
      'Multiple physical $platform devices are connected; pass --device-id. '
      'Available: ${physical.map((device) => device.id).join(', ')}',
    );
  }
  return physical.single;
}

String renderPhysicalSmokeReport({
  required PhysicalSmokeOptions options,
  required FlutterDevice device,
  required String nativeArtifact,
  required CommandOutcome conversion,
  CommandOutcome? release,
  required DateTime completedAt,
}) {
  final passed = conversion.succeeded && (release?.succeeded ?? true);
  final buffer = StringBuffer()
    ..writeln('# Physical Native Smoke')
    ..writeln()
    ..writeln('- Completed: ${completedAt.toUtc().toIso8601String()}')
    ..writeln('- Platform: ${options.platform}')
    ..writeln('- Device: ${device.name}')
    ..writeln('- Device ID: ${device.id}')
    ..writeln('- Target: ${device.targetPlatform}')
    ..writeln('- SDK: ${device.sdk}')
    ..writeln('- Native artifact: $nativeArtifact')
    ..writeln('- Conversion harness: ${conversion.command}')
    ..writeln('- Conversion result: ${conversion.succeeded ? 'PASS' : 'FAIL'}')
    ..writeln(
      '- Release artifact: '
      '${options.releaseArtifact ?? 'not supplied'}',
    );
  if (release != null) {
    buffer
      ..writeln('- Release command: ${release.command}')
      ..writeln('- Release result: ${release.succeeded ? 'PASS' : 'FAIL'}');
  }
  buffer
    ..writeln()
    ..writeln('## Overall')
    ..writeln()
    ..writeln(
      passed ? (release == null ? 'PASS (conversion only)' : 'PASS') : 'FAIL',
    )
    ..writeln()
    ..writeln('## Conversion log tail')
    ..writeln()
    ..writeln('```text')
    ..writeln(_tail(conversion.output))
    ..writeln('```');
  if (release != null) {
    buffer
      ..writeln()
      ..writeln('## Release install/launch log tail')
      ..writeln()
      ..writeln('```text')
      ..writeln(_tail(release.output))
      ..writeln('```');
  }
  return buffer.toString();
}

Future<void> main(List<String> arguments) async {
  try {
    final options = PhysicalSmokeOptions.parse(arguments);
    final appDirectory = Directory.current;
    final repositoryRoot = appDirectory.parent;
    final device = await _findDevice(options);
    final nativeArtifact = _verifyNativeArtifact(
      repositoryRoot,
      options.platform,
    );

    final conversion = await _runCommand('flutter', [
      'test',
      nativeSmokeTest,
      '-d',
      device.id,
    ], workingDirectory: appDirectory.path);

    CommandOutcome? release;
    if (options.releaseArtifact != null) {
      release = await _runReleaseSmoke(options, device);
    }

    final report = renderPhysicalSmokeReport(
      options: options,
      device: device,
      nativeArtifact: nativeArtifact,
      conversion: conversion,
      release: release,
      completedAt: DateTime.now(),
    );
    final reportFile = File(options.reportPath);
    await reportFile.parent.create(recursive: true);
    await reportFile.writeAsString(report);
    stdout.writeln('Physical smoke report: ${reportFile.absolute.path}');

    if (!conversion.succeeded || (release != null && !release.succeeded)) {
      exitCode = 1;
    }
  } on PhysicalSmokeException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  }
}

Future<FlutterDevice> _findDevice(PhysicalSmokeOptions options) async {
  final outcome = await _runCommand('flutter', ['devices', '--machine']);
  if (!outcome.succeeded) {
    throw PhysicalSmokeException(
      'flutter devices failed:\n${_tail(outcome.output)}',
    );
  }
  return selectPhysicalDevice(
    parseFlutterDevices(outcome.output),
    platform: options.platform,
    requestedId: options.deviceId,
  );
}

String _verifyNativeArtifact(Directory repositoryRoot, String platform) {
  if (platform == 'android') {
    final directory = Directory(
      '${repositoryRoot.path}/rust/target/android/jniLibs',
    );
    if (!directory.existsSync()) {
      throw const PhysicalSmokeException(
        'Android native libraries are missing. Run '
        'rust/tool/build-mobile-android.ps1 first.',
      );
    }
    final libraries = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.so'))
        .toList(growable: false);
    if (libraries.isEmpty) {
      throw const PhysicalSmokeException(
        'Android native libraries are missing. Run '
        'rust/tool/build-mobile-android.ps1 first.',
      );
    }
    return libraries.map((file) => file.path).join(', ');
  }

  final library = File(
    '${repositoryRoot.path}/rust/target/ios/'
    'UniversalReaderNative.xcframework/ios-arm64/'
    'libuniversal_reader_native.a',
  );
  if (!library.existsSync()) {
    throw const PhysicalSmokeException(
      'iOS device XCFramework is missing. Run '
      'rust/tool/build-mobile-ios.sh on macOS first.',
    );
  }
  return library.path;
}

Future<CommandOutcome> _runReleaseSmoke(
  PhysicalSmokeOptions options,
  FlutterDevice device,
) async {
  final artifact = File(options.releaseArtifact!);
  if (!artifact.existsSync()) {
    throw PhysicalSmokeException(
      'Release artifact does not exist: ${artifact.path}',
    );
  }

  if (options.platform == 'android') {
    final install = await _runCommand('adb', [
      '-s',
      device.id,
      'install',
      '-r',
      artifact.path,
    ]);
    if (!install.succeeded) return install;
    final launch = await _runCommand('adb', [
      '-s',
      device.id,
      'shell',
      'monkey',
      '-p',
      androidApplicationId,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
    if (!launch.succeeded) return launch;
    await Future<void>.delayed(const Duration(seconds: 5));
    final process = await _runCommand('adb', [
      '-s',
      device.id,
      'shell',
      'pidof',
      androidApplicationId,
    ]);
    return CommandOutcome(
      command: '${install.command}; ${launch.command}; ${process.command}',
      exitCode: process.exitCode,
      output: '${install.output}\n${launch.output}\n${process.output}',
    );
  }

  if (!Platform.isMacOS) {
    throw const PhysicalSmokeException(
      'The iOS release artifact smoke must run on macOS.',
    );
  }
  if (!artifact.path.endsWith('.app')) {
    throw const PhysicalSmokeException(
      'Pass the signed Runner.app path for iOS, not an IPA.',
    );
  }
  final install = await _runCommand('xcrun', [
    'devicectl',
    'device',
    'install',
    'app',
    '--device',
    device.id,
    artifact.path,
  ]);
  if (!install.succeeded) return install;
  final launch = await _runCommand('xcrun', [
    'devicectl',
    'device',
    'process',
    'launch',
    '--device',
    device.id,
    iosBundleId,
  ]);
  return CommandOutcome(
    command: '${install.command}; ${launch.command}',
    exitCode: launch.exitCode,
    output: '${install.output}\n${launch.output}',
  );
}

Future<CommandOutcome> _runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final output = StringBuffer();
  final stdoutDone = process.stdout.transform(utf8.decoder).forEach((chunk) {
    stdout.write(chunk);
    output.write(chunk);
  });
  final stderrDone = process.stderr.transform(utf8.decoder).forEach((chunk) {
    stderr.write(chunk);
    output.write(chunk);
  });
  final code = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  return CommandOutcome(
    command: [executable, ...arguments].join(' '),
    exitCode: code,
    output: output.toString(),
  );
}

String _tail(String value, {int maxCharacters = 16000}) {
  if (value.length <= maxCharacters) return value;
  return value.substring(value.length - maxCharacters);
}
