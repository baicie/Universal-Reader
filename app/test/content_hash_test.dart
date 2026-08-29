import 'package:app/core/content_hash.dart';
import 'package:app/core/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hashes the file bytes, not the name', () {
    expect(contentHash([1, 2, 3]), contentHash([1, 2, 3]));
    expect(contentHash([1, 2, 3]), isNot(contentHash([1, 2, 4])));
  });

  test('in-memory import deduplicates by content hash', () async {
    final repository = InMemoryLibraryRepository();
    final first = await repository.importBytes('a.txt', [9, 8, 7]);
    final second = await repository.importBytes('b.txt', [9, 8, 7]);
    expect(second.metadata.id, first.metadata.id);
    expect(await repository.load(), hasLength(1));
  });
}
