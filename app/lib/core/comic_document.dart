import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:koni_archive_core/koni_archive_core.dart';
import 'package:koni_rar/koni_rar.dart';

import 'cover_extract.dart';
import 'models.dart';
import 'reader_runtime.dart';

const _maxRarEntries = 10000;
const _maxRarEntryBytes = 64 * 1024 * 1024;

class ComicPage {
  const ComicPage({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class ComicReaderDocument implements ChapteredDocument {
  ComicReaderDocument._({required this.metadata, required this.pages});

  factory ComicReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    final pages = _zipPages(bytes);
    return ComicReaderDocument._(metadata: metadata, pages: pages);
  }

  static Future<ComicReaderDocument> parseAsync({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) async {
    if (!_isRar(bytes)) {
      return ComicReaderDocument.parse(metadata: metadata, bytes: bytes);
    }
    final pages = await _rarPages(bytes);
    return ComicReaderDocument._(metadata: metadata, pages: pages);
  }

  static List<ComicPage> _zipPages(List<int> bytes) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('corrupt comic');
    }
    final pages = <ComicPage>[];
    for (final file in archive) {
      if (!file.isFile || !looksLikeImageName(file.name)) continue;
      pages.add(
        ComicPage(
          name: file.name.replaceAll('\\', '/').split('/').last,
          bytes: List<int>.from(file.content as List<int>),
        ),
      );
    }
    pages.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (pages.isEmpty) {
      throw const FormatException('corrupt comic');
    }
    return pages;
  }

  static Future<List<ComicPage>> _rarPages(List<int> bytes) async {
    final source = MemoryByteSource(
      Uint8List.fromList(bytes),
      name: 'comic.cbr',
    );
    ArchiveReader? reader;
    try {
      reader = await const RarFormat().openReader(
        source,
        const ArchiveReadOptions(
          maxEntryCount: _maxRarEntries,
          maxEntrySize: _maxRarEntryBytes,
        ),
      );
      final pages = <ComicPage>[];
      for (final entry in reader.entries) {
        if (entry.type != ArchiveEntryType.file ||
            !looksLikeImageName(entry.path)) {
          continue;
        }
        final output = BytesBuilder(copy: false);
        await for (final chunk in reader.openRead(entry)) {
          output.add(chunk);
        }
        pages.add(
          ComicPage(
            name: entry.path.replaceAll('\\', '/').split('/').last,
            bytes: output.takeBytes(),
          ),
        );
      }
      pages.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (pages.isEmpty) {
        throw const FormatException('corrupt comic');
      }
      return pages;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('corrupt comic');
    } finally {
      await reader?.close();
      await source.close();
    }
  }

  @override
  final DocumentMetadata metadata;
  final List<ComicPage> pages;
  int pageIndex = 0;

  ComicPage get currentPage => pages[pageIndex.clamp(0, pages.length - 1)];

  @override
  int get chapterIndex => pageIndex;

  @override
  int get chapterCount => pages.length;

  @override
  String get currentChapterText => currentPage.name;

  @override
  bool get truncated => false;

  @override
  Locator locatorForProgress(double progress) {
    final index = (progress.clamp(0, 0.999) * pages.length).floor();
    return ComicLocator(page: index + 1);
  }

  @override
  Future<Locator> currentLocator() async => ComicLocator(page: pageIndex + 1);

  @override
  Future<String?> extractText(DocumentRange range) async => currentPage.name;

  @override
  Future<void> goTo(Locator locator) async {
    switch (locator) {
      case ComicLocator(:final page):
        pageIndex = (page - 1).clamp(0, pages.length - 1);
      case TextLocator(:final offset):
        pageIndex = offset.clamp(0, pages.length - 1);
      default:
        break;
    }
  }

  @override
  Stream<double> get progress => Stream<double>.value(
    pages.length <= 1 ? 0 : pageIndex / (pages.length - 1),
  );

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    return [
      for (final page in pages)
        if (page.name.toLowerCase().contains(query.toLowerCase()))
          SearchResult(
            title: page.name,
            excerpt: page.name,
            locator: ComicLocator(page: pages.indexOf(page) + 1),
          ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      for (var i = 0; i < pages.length; i++)
        TocItem(
          title: pages[i].name,
          locator: ComicLocator(page: i + 1),
        ),
    ];
  }
}

bool _isRar(List<int> bytes) {
  if (bytes.length < 7) return false;
  const signature = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return bytes[6] == 0x00 || bytes[6] == 0x01;
}
