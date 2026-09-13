import 'dart:io';

import 'package:app/core/native_format_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rustSource = File('../rust/crates/reader-mobile/src/lib.rs')
      .readAsStringSync();
  final header = File(
    '../rust/crates/reader-mobile/include/universal_reader_native.h',
  ).readAsStringSync();

  test('Dart, Rust, and C header agree on the native API version', () {
    final rustVersion = RegExp(r'UR_NATIVE_API_VERSION:\s*u32\s*=\s*(\d+);')
        .firstMatch(rustSource)
        ?.group(1);
    final headerVersion = RegExp(r'#define\s+UR_NATIVE_API_VERSION\s+(\d+)u')
        .firstMatch(header)
        ?.group(1);

    expect(rustVersion, isNotNull);
    expect(headerVersion, isNotNull);
    expect(int.parse(rustVersion!), supportedNativeFormatApiVersion);
    expect(int.parse(headerVersion!), supportedNativeFormatApiVersion);
  });
}
