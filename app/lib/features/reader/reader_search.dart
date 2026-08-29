import '../../core/reader_runtime.dart';

Future<List<SearchResult>> hitsForQuery(
  ReaderDocument document,
  String query,
) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  return document.search(trimmed);
}
