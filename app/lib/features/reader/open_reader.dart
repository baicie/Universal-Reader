import '../../core/comic_document.dart';
import '../../core/docx_document.dart';
import '../../core/epub_document.dart';
import '../../core/fb2_document.dart';
import '../../core/mobi_document.dart';
import '../../core/models.dart';
import '../../core/odt_document.dart';
import '../../core/pdf_document.dart';
import '../../core/reader_runtime.dart';
import '../../core/rtf_document.dart';
import '../../core/text_document.dart';

Future<ReaderDocument> openReaderDocumentAsync({
  required DocumentMetadata metadata,
  List<int>? bytes,
}) async {
  if (bytes != null &&
      bytes.isNotEmpty &&
      (metadata.format == DocumentFormat.cbz ||
          metadata.format == DocumentFormat.cbr ||
          metadata.format == DocumentFormat.cbt)) {
    try {
      return await ComicReaderDocument.parseAsync(
        metadata: metadata,
        bytes: bytes,
      );
    } on FormatException {
      return CorruptReaderDocument(metadata: metadata);
    }
  }
  return openReaderDocument(metadata: metadata, bytes: bytes);
}

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
    if (metadata.format == DocumentFormat.docx) {
      try {
        return DocxReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.odt) {
      try {
        return OdtReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
    }
    if (metadata.format == DocumentFormat.rtf) {
      try {
        return RtfReaderDocument.parse(metadata: metadata, bytes: bytes);
      } on FormatException {
        return CorruptReaderDocument(metadata: metadata);
      }
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
        metadata.format == DocumentFormat.cbr ||
        metadata.format == DocumentFormat.cbt) {
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
