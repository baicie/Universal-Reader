import '../../core/comic_document.dart';
import '../../core/docx_document.dart';
import '../../core/epub_document.dart';
import '../../core/fb2_document.dart';
import '../../core/format_detector.dart';
import '../../core/mobi_document.dart';
import '../../core/models.dart';
import '../../core/odt_document.dart';
import '../../core/pdf_document.dart';
import '../../core/reader_runtime.dart';
import '../../core/rtf_document.dart';
import '../../core/text_document.dart';

abstract class ReaderFormatAdapter implements DocumentAdapter {
  const ReaderFormatAdapter({required this.id, required this.formats});

  @override
  final String id;
  final Set<DocumentFormat> formats;

  @override
  Future<double> sniff(DocumentSource source) async {
    final detected = const FormatDetector().detect(source);
    return formats.contains(detected) ? 1 : 0;
  }

  ReaderDocument openSync(DocumentSource source);

  @override
  Future<ReaderDocument> open(DocumentSource source) async => openSync(source);

  DocumentMetadata metadataFor(DocumentSource source) {
    final provided = source.metadata;
    if (provided != null) return provided;
    final format = const FormatDetector().detect(source);
    return DocumentMetadata(
      id: source.name,
      title: source.name,
      author: '',
      format: format,
      type: format.type,
    );
  }
}

class ReaderAdapterRegistry {
  ReaderAdapterRegistry(Iterable<ReaderFormatAdapter> adapters) {
    for (final adapter in adapters) {
      for (final format in adapter.formats) {
        if (_byFormat.containsKey(format)) {
          throw StateError('duplicate reader adapter for ${format.name}');
        }
        _byFormat[format] = adapter;
      }
    }
  }

  static final standard = ReaderAdapterRegistry(const [
    TextFormatAdapter(),
    DocxFormatAdapter(),
    OdtFormatAdapter(),
    RtfFormatAdapter(),
    EpubFormatAdapter(),
    PdfFormatAdapter(),
    Fb2FormatAdapter(),
    MobiFormatAdapter(),
    ComicFormatAdapter(),
  ]);

  final Map<DocumentFormat, ReaderFormatAdapter> _byFormat = {};

  Set<DocumentFormat> get formats => Set.unmodifiable(_byFormat.keys);

  Set<ReaderFormatAdapter> get adapters =>
      Set.unmodifiable(_byFormat.values.toSet());

  ReaderDocument openSync({
    required DocumentMetadata metadata,
    required List<int>? bytes,
  }) {
    if (bytes == null || bytes.isEmpty) {
      return UnavailableReaderDocument(metadata: metadata);
    }
    final adapter = _byFormat[metadata.format];
    if (adapter == null) return UnavailableReaderDocument(metadata: metadata);
    try {
      return adapter.openSync(
        DocumentSource(name: metadata.id, bytes: bytes, metadata: metadata),
      );
    } on FormatException {
      return CorruptReaderDocument(metadata: metadata);
    }
  }

  Future<ReaderDocument> open({
    required DocumentMetadata metadata,
    required List<int>? bytes,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return UnavailableReaderDocument(metadata: metadata);
    }
    final adapter = _byFormat[metadata.format];
    if (adapter == null) return UnavailableReaderDocument(metadata: metadata);
    try {
      return await adapter.open(
        DocumentSource(name: metadata.id, bytes: bytes, metadata: metadata),
      );
    } on FormatException {
      return CorruptReaderDocument(metadata: metadata);
    }
  }
}

class TextFormatAdapter extends ReaderFormatAdapter {
  const TextFormatAdapter()
    : super(
        id: 'text',
        formats: const {
          DocumentFormat.txt,
          DocumentFormat.markdown,
          DocumentFormat.html,
        },
      );

  @override
  ReaderDocument openSync(DocumentSource source) => TextReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class DocxFormatAdapter extends ReaderFormatAdapter {
  const DocxFormatAdapter()
    : super(id: 'docx', formats: const {DocumentFormat.docx});

  @override
  ReaderDocument openSync(DocumentSource source) => DocxReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class OdtFormatAdapter extends ReaderFormatAdapter {
  const OdtFormatAdapter()
    : super(id: 'odt', formats: const {DocumentFormat.odt});

  @override
  ReaderDocument openSync(DocumentSource source) => OdtReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class RtfFormatAdapter extends ReaderFormatAdapter {
  const RtfFormatAdapter()
    : super(id: 'rtf', formats: const {DocumentFormat.rtf});

  @override
  ReaderDocument openSync(DocumentSource source) => RtfReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class EpubFormatAdapter extends ReaderFormatAdapter {
  const EpubFormatAdapter()
    : super(id: 'epub', formats: const {DocumentFormat.epub});

  @override
  ReaderDocument openSync(DocumentSource source) => EpubReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class PdfFormatAdapter extends ReaderFormatAdapter {
  const PdfFormatAdapter()
    : super(id: 'pdf', formats: const {DocumentFormat.pdf});

  @override
  ReaderDocument openSync(DocumentSource source) => PdfReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class Fb2FormatAdapter extends ReaderFormatAdapter {
  const Fb2FormatAdapter()
    : super(id: 'fb2', formats: const {DocumentFormat.fb2});

  @override
  ReaderDocument openSync(DocumentSource source) => Fb2ReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class MobiFormatAdapter extends ReaderFormatAdapter {
  const MobiFormatAdapter()
    : super(
        id: 'mobi',
        formats: const {DocumentFormat.mobi, DocumentFormat.azw3},
      );

  @override
  ReaderDocument openSync(DocumentSource source) => MobiReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class ComicFormatAdapter extends ReaderFormatAdapter {
  const ComicFormatAdapter()
    : super(
        id: 'comic',
        formats: const {
          DocumentFormat.cbz,
          DocumentFormat.cbr,
          DocumentFormat.cbt,
          DocumentFormat.cb7,
        },
      );

  @override
  ReaderDocument openSync(DocumentSource source) => ComicReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );

  @override
  Future<ReaderDocument> open(DocumentSource source) {
    return ComicReaderDocument.parseAsync(
      metadata: metadataFor(source),
      bytes: source.bytes!,
    );
  }
}
