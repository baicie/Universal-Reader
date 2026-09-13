import '../../core/models.dart';
import '../../core/reader_runtime.dart';
import 'reader_adapter_registry.dart';

Future<ReaderDocument> openReaderDocumentAsync({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) async {
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
