import '../../core/models.dart';
import '../../core/native_format_converter.dart';
import '../../core/reader_runtime.dart';
import '../../core/text_document.dart';
import 'reader_adapter_registry.dart';

NativeFormatConverter? Function() nativeFormatConverterFactory =
    createNativeFormatConverter;

Future<ReaderDocument> openReaderDocumentAsync({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) async {
  if (bytes != null &&
      bytes.isNotEmpty &&
      (metadata.format == DocumentFormat.chm ||
          metadata.format == DocumentFormat.djvu)) {
    final converter = nativeFormatConverterFactory();
    if (converter != null) {
      final converted = metadata.format == DocumentFormat.chm
          ? await converter.chmToEpub(fileName: metadata.id, bytes: bytes)
          : await converter.djvuToCbz(bytes: bytes);
      if (converted != null && converted.isNotEmpty) {
        final format = metadata.format == DocumentFormat.chm
            ? DocumentFormat.epub
            : DocumentFormat.cbz;
        return ReaderAdapterRegistry.standard.open(
          metadata: metadata.copyWith(format: format, type: format.type),
          bytes: converted,
        );
      }
    }
    return UnavailableReaderDocument(metadata: metadata);
  }
  return ReaderAdapterRegistry.standard.open(metadata: metadata, bytes: bytes);
}

ReaderDocument openReaderDocument({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) {
  return ReaderAdapterRegistry.standard.openSync(
    metadata: metadata,
    bytes: bytes,
  );
}
