import 'native_format_converter_stub.dart'
    if (dart.library.io) 'native_format_converter_io.dart'
    as implementation;

const supportedNativeFormatApiVersion = 1;

abstract interface class NativeFormatConverter {
  int get apiVersion;

  Future<List<int>?> chmToEpub({
    required String fileName,
    required List<int> bytes,
  });

  Future<List<int>?> djvuToCbz({required List<int> bytes});
}

NativeFormatConverter? createNativeFormatConverter() {
  return implementation.createNativeFormatConverter();
}

String? get nativeFormatLoadError => implementation.nativeFormatLoadError;
