import '../../core/comic_document.dart';
import '../../core/epub_document.dart';
import '../../core/fb2_document.dart';
import '../../core/mobi_document.dart';
import '../../core/models.dart';
import '../../core/pdf_document.dart';
import '../../core/reader_runtime.dart';
import '../../core/text_document.dart';

ReaderDocument openReaderDocument({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) {
  if (bytes != null && bytes.isNotEmpty) {
    if (metadata.format == DocumentFormat.txt ||
        metadata.format == DocumentFormat.markdown) {
      try {
        return TextReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.html) {
      return TextReaderDocument.parse(metadata: metadata, bytes: bytes);
    }
    if (metadata.format == DocumentFormat.epub) {
      try {
        return EpubReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.pdf) {
      try {
        return PdfReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.cbz ||
        metadata.format == DocumentFormat.cbr) {
      try {
        return ComicReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.fb2) {
      try {
        return Fb2ReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.mobi ||
        metadata.format == DocumentFormat.azw3) {
      try {
        return MobiReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    return UnavailableReaderDocument(metadata: metadata);
  }
  return UnavailableReaderDocument(metadata: metadata);
}
