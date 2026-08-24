import 'models.dart';

class FormatDetector {
  const FormatDetector();

  DocumentFormat detect(DocumentSource source) {
    final name = source.name.toLowerCase();
    if (name.endsWith('.epub')) return DocumentFormat.epub;
    if (name.endsWith('.pdf')) return DocumentFormat.pdf;
    if (name.endsWith('.mobi')) return DocumentFormat.mobi;
    if (name.endsWith('.azw3')) return DocumentFormat.azw3;
    if (name.endsWith('.fb2')) return DocumentFormat.fb2;
    if (name.endsWith('.txt')) return DocumentFormat.txt;
    if (name.endsWith('.md') || name.endsWith('.markdown')) {
      return DocumentFormat.markdown;
    }
    if (name.endsWith('.html') || name.endsWith('.htm')) {
      return DocumentFormat.html;
    }
    if (name.endsWith('.cbz')) return DocumentFormat.cbz;
    if (name.endsWith('.cbr')) return DocumentFormat.cbr;
    return DocumentFormat.unknown;
  }
}
