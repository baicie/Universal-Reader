import '../../core/models.dart';
import '../../core/reader_runtime.dart';
import '../../core/text_document.dart';
import '../tools/sample_reader_document.dart';

const seedDocumentIds = {
  'design',
  'creative',
  'data',
  'prince',
  'science',
  'patterns',
  'solitude',
  'code',
  'galaxy',
  'rust',
};

ReaderDocument openReaderDocument({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) {
  if (bytes != null && bytes.isNotEmpty && metadata.format.isPlainText) {
    return TextReaderDocument.parse(metadata: metadata, bytes: bytes);
  }
  if (seedDocumentIds.contains(metadata.id) &&
      (bytes == null || bytes.isEmpty)) {
    return SampleReaderDocument(metadata: metadata);
  }
  return UnavailableReaderDocument(metadata: metadata);
}
