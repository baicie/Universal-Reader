enum DocumentFormat {
  epub,
  pdf,
  mobi,
  azw3,
  fb2,
  txt,
  markdown,
  html,
  cbz,
  cbr,
  unknown,
}

enum DocumentType { reflow, fixedPage, comic }

extension DocumentFormatLabel on DocumentFormat {
  String get label => switch (this) {
    DocumentFormat.epub => 'EPUB',
    DocumentFormat.pdf => 'PDF',
    DocumentFormat.mobi => 'MOBI',
    DocumentFormat.azw3 => 'AZW3',
    DocumentFormat.fb2 => 'FB2',
    DocumentFormat.txt => 'TXT',
    DocumentFormat.markdown => 'MD',
    DocumentFormat.html => 'HTML',
    DocumentFormat.cbz => 'CBZ',
    DocumentFormat.cbr => 'CBR',
    DocumentFormat.unknown => 'FILE',
  };

  DocumentType get type => switch (this) {
    DocumentFormat.pdf => DocumentType.fixedPage,
    DocumentFormat.cbz || DocumentFormat.cbr => DocumentType.comic,
    _ => DocumentType.reflow,
  };
}

class DocumentSource {
  const DocumentSource({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final List<int>? bytes;
}

class DocumentMetadata {
  const DocumentMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.type,
    this.coverColor = 0xFF527882,
    this.contentHash = '',
    this.hasCover = false,
  });

  final String id;
  final String title;
  final String author;
  final DocumentFormat format;
  final DocumentType type;
  final int coverColor;
  final String contentHash;
  final bool hasCover;

  DocumentMetadata copyWith({
    String? id,
    String? title,
    String? author,
    DocumentFormat? format,
    DocumentType? type,
    int? coverColor,
    String? contentHash,
    bool? hasCover,
  }) {
    return DocumentMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      type: type ?? this.type,
      coverColor: coverColor ?? this.coverColor,
      contentHash: contentHash ?? this.contentHash,
      hasCover: hasCover ?? this.hasCover,
    );
  }
}

class ReadingState {
  const ReadingState({required this.progress, required this.lastOpened});

  final double progress;
  final DateTime lastOpened;
}

class LibraryDocument {
  const LibraryDocument({required this.metadata, required this.readingState});

  final DocumentMetadata metadata;
  final ReadingState readingState;

  LibraryDocument copyWith({
    DocumentMetadata? metadata,
    ReadingState? readingState,
  }) => LibraryDocument(
    metadata: metadata ?? this.metadata,
    readingState: readingState ?? this.readingState,
  );
}

sealed class Locator {
  const Locator();
}

class PdfLocator extends Locator {
  const PdfLocator({required this.page, this.x, this.y});
  final int page;
  final double? x;
  final double? y;
}

class EpubLocator extends Locator {
  const EpubLocator({
    required this.href,
    this.cfi,
    this.progression,
    this.fragment,
  });
  final String href;
  final String? cfi;
  final double? progression;
  final String? fragment;
}

class TextLocator extends Locator {
  const TextLocator({required this.offset});
  final int offset;
}

class ComicLocator extends Locator {
  const ComicLocator({required this.page});
  final int page;
}
