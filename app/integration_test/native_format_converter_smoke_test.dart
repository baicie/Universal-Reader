import 'package:app/core/comic_document.dart';
import 'package:app/core/epub_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/native_format_converter.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _chmSha256 =
    'bce781f8860caee2500781656bef068e1dc8a0992c1f2b66d5cbba030492feec';
const _djvuSha256 =
    'cb350857155f9132b43174130b6910bf1d4a034beeeec958b9c23ff37c278245';

Future<Uint8List> _loadAsset(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

DocumentMetadata _metadata(String id, DocumentFormat format) {
  return DocumentMetadata(
    id: id,
    title: id,
    author: '',
    format: format,
    type: format.type,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native CHM and DjVu bridge converts corpus fixtures', (
    tester,
  ) async {
    final chm = await _loadAsset('assets/test-books/chm/minimal.chm');
    final djvu = await _loadAsset('assets/test-books/djvu/minimal.djvu');

    expect(sha256.convert(chm).toString(), _chmSha256);
    expect(sha256.convert(djvu).toString(), _djvuSha256);
    final converter = createNativeFormatConverter();
    expect(
      converter,
      isNotNull,
      reason: 'The native library was not found by DynamicLibrary.',
    );
    expect(converter!.apiVersion, supportedNativeFormatApiVersion);
    expect(nativeFormatLoadError, isNull);

    final chmDocument = await openReaderDocumentAsync(
      metadata: _metadata('minimal.chm', DocumentFormat.chm),
      bytes: chm,
    );
    expect(chmDocument, isA<EpubReaderDocument>());
    expect(chmDocument.metadata.format, DocumentFormat.epub);
    expect((chmDocument as ChapteredDocument).chapterCount, greaterThan(0));

    final djvuDocument = await openReaderDocumentAsync(
      metadata: _metadata('minimal.djvu', DocumentFormat.djvu),
      bytes: djvu,
    );
    expect(djvuDocument, isA<ComicReaderDocument>());
    expect(djvuDocument.metadata.format, DocumentFormat.cbz);
    expect((djvuDocument as ChapteredDocument).chapterCount, greaterThan(0));
  });
}
