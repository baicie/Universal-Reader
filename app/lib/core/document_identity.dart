import 'epub_document.dart';
import 'fb2_document.dart';
import 'models.dart';

class DocumentIdentity {
  const DocumentIdentity({required this.title, required this.author});

  final String title;
  final String author;
}

String titleFromFileName(String fileName) {
  return fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
}

DocumentIdentity documentIdentity({
  required String fileName,
  required List<int> bytes,
  required DocumentFormat format,
}) {
  final fallback = titleFromFileName(fileName);
  try {
    switch (format) {
      case DocumentFormat.epub:
      case DocumentFormat.azw3:
      case DocumentFormat.mobi:
        final parsed = parseEpub(bytes);
        return DocumentIdentity(
          title: parsed.title.trim().isEmpty ? fallback : parsed.title.trim(),
          author: parsed.author.trim(),
        );
      case DocumentFormat.fb2:
        final parsed = parseFb2(bytes);
        return DocumentIdentity(
          title: parsed.title.trim().isEmpty ? fallback : parsed.title.trim(),
          author: parsed.author.trim(),
        );
      default:
        return DocumentIdentity(title: fallback, author: '');
    }
  } on FormatException {
    return DocumentIdentity(title: fallback, author: '');
  }
}
