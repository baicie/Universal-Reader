import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_format_converter.dart';

const _ok = 0;

final class _UrBytes extends Struct {
  external Pointer<Uint8> data;
  @Size()
  external int len;
  @Size()
  external int capacity;
}

typedef _ChmNative = Int32 Function(
  Pointer<Uint8>,
  Size,
  Pointer<Uint8>,
  Size,
  Pointer<_UrBytes>,
);
typedef _ChmDart = int Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
  Pointer<_UrBytes>,
);
typedef _DjvuNative = Int32 Function(Pointer<Uint8>, Size, Pointer<_UrBytes>);
typedef _DjvuDart = int Function(Pointer<Uint8>, int, Pointer<_UrBytes>);
typedef _VersionNative = Uint32 Function();
typedef _VersionDart = int Function();
typedef _FreeNative = Void Function(_UrBytes);
typedef _FreeDart = void Function(_UrBytes);

class _NativeFormatConverter implements NativeFormatConverter {
  _NativeFormatConverter(DynamicLibrary library)
    : apiVersion = _readApiVersion(library),
      _chm = library.lookupFunction<_ChmNative, _ChmDart>('ur_chm_to_epub'),
      _djvu = library.lookupFunction<_DjvuNative, _DjvuDart>('ur_djvu_to_cbz'),
      _free = library.lookupFunction<_FreeNative, _FreeDart>('ur_bytes_free');

  @override
  final int apiVersion;
  final _ChmDart _chm;
  final _DjvuDart _djvu;
  final _FreeDart _free;

  @override
  Future<List<int>?> chmToEpub({
    required String fileName,
    required List<int> bytes,
  }) async {
    final name = utf8.encode(fileName);
    final namePointer = calloc<Uint8>(name.length);
    final input = calloc<Uint8>(bytes.length);
    final output = calloc<_UrBytes>();
    try {
      namePointer.asTypedList(name.length).setAll(0, name);
      input.asTypedList(bytes.length).setAll(0, bytes);
      final status = _chm(
        namePointer,
        name.length,
        input,
        bytes.length,
        output,
      );
      return _readOutput(status, output);
    } finally {
      calloc.free(namePointer);
      calloc.free(input);
      calloc.free(output);
    }
  }

  @override
  Future<List<int>?> djvuToCbz({required List<int> bytes}) async {
    final input = calloc<Uint8>(bytes.length);
    final output = calloc<_UrBytes>();
    try {
      input.asTypedList(bytes.length).setAll(0, bytes);
      final status = _djvu(input, bytes.length, output);
      return _readOutput(status, output);
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  List<int>? _readOutput(int status, Pointer<_UrBytes> output) {
    final value = output.ref;
    if (value.data == nullptr) return null;
    try {
      if (status != _ok || value.len == 0) return null;
      return Uint8List.fromList(value.data.asTypedList(value.len));
    } finally {
      _free(value);
    }
  }
}

int _readApiVersion(DynamicLibrary library) {
  final version = library.lookupFunction<_VersionNative, _VersionDart>(
    'ur_native_api_version',
  )();
  if (version != supportedNativeFormatApiVersion) {
    throw StateError(
      'Unsupported native format API version $version; '
      'expected $supportedNativeFormatApiVersion.',
    );
  }
  return version;
}

NativeFormatConverter? _cached;
bool _attempted = false;
String? _loadError;

String? get nativeFormatLoadError => _loadError;

NativeFormatConverter? createNativeFormatConverter() {
  if (_attempted) return _cached;
  _attempted = true;
  final library = _openLibrary();
  if (library == null) {
    _loadError = 'Native library was not found.';
    return null;
  }
  try {
    _cached = _NativeFormatConverter(library);
  } on ArgumentError catch (error) {
    _loadError = 'Native library symbol lookup failed: $error';
    return null;
  } on StateError catch (error) {
    _loadError = error.message;
    return null;
  }
  return _cached;
}

DynamicLibrary? _openLibrary() {
  for (final name in _candidateLibraries()) {
    try {
      return name == null
          ? DynamicLibrary.process()
          : DynamicLibrary.open(name);
    } on ArgumentError {
      continue;
    }
  }
  return null;
}

List<String?> _candidateLibraries() {
  if (Platform.isAndroid) return const ['libuniversal_reader_native.so'];
  if (Platform.isIOS || Platform.isMacOS) {
    return const [
      null,
      'UniversalReaderNative.framework/UniversalReaderNative',
    ];
  }
  if (Platform.isLinux) return const ['libuniversal_reader_native.so'];
  if (Platform.isWindows) return const ['universal_reader_native.dll'];
  return const [];
}
