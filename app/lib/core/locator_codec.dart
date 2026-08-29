import 'models.dart';

String encodeLocator(Locator locator) {
  return switch (locator) {
    EpubLocator(:final href, :final cfi, :final progression) => [
      'epub',
      href,
      if (cfi != null && cfi.isNotEmpty) 'cfi=$cfi',
      if (progression != null) 'p=$progression',
    ].join('|'),
    PdfLocator(:final page) => 'pdf|$page',
    ComicLocator(:final page) => 'comic|$page',
    TextLocator(:final offset) => 'text|$offset',
  };
}

Locator? decodeLocator(String label) {
  final parts = label.split('|');
  if (parts.isEmpty || parts.first.isEmpty) return null;
  switch (parts.first) {
    case 'epub':
      if (parts.length < 2) return null;
      String? cfi;
      double? progression;
      for (final part in parts.skip(2)) {
        if (part.startsWith('cfi=')) cfi = part.substring(4);
        if (part.startsWith('p=')) {
          progression = double.tryParse(part.substring(2));
        }
      }
      return EpubLocator(href: parts[1], cfi: cfi, progression: progression);
    case 'pdf':
      if (parts.length < 2) return null;
      final page = int.tryParse(parts[1]);
      return page == null ? null : PdfLocator(page: page);
    case 'comic':
      if (parts.length < 2) return null;
      final page = int.tryParse(parts[1]);
      return page == null ? null : ComicLocator(page: page);
    case 'text':
      if (parts.length < 2) return null;
      final offset = int.tryParse(parts[1]);
      return offset == null ? null : TextLocator(offset: offset);
    default:
      return null;
  }
}
