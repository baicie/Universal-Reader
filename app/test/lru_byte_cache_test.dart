import 'package:app/core/lru_byte_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evicts the least recently used entry at the entry limit', () {
    final cache = LruByteCache(maxEntries: 2, maxBytes: 100, maxEntryBytes: 20);
    cache.put('a', [1]);
    cache.put('b', [2]);
    expect(cache.get('a'), [1]);
    cache.put('c', [3]);

    expect(cache.get('b'), isNull);
    expect(cache.get('a'), [1]);
    expect(cache.get('c'), [3]);
  });

  test('evicts entries until the byte budget fits', () {
    final cache = LruByteCache(maxEntries: 10, maxBytes: 6, maxEntryBytes: 4);
    cache.put('a', [1, 2, 3]);
    cache.put('b', [4, 5, 6]);
    cache.put('c', [7, 8, 9]);

    expect(cache.get('a'), isNull);
    expect(cache.get('b'), [4, 5, 6]);
    expect(cache.get('c'), [7, 8, 9]);
  });

  test('does not cache an entry larger than the per-item limit', () {
    final cache = LruByteCache(maxEntryBytes: 2);
    cache.put('large', [1, 2, 3]);
    expect(cache.get('large'), isNull);
    expect(cache.length, 0);
  });

  test('returned bytes cannot mutate the cached value', () {
    final cache = LruByteCache();
    cache.put('key', [1, 2, 3]);
    final bytes = cache.get('key')!;
    expect(() => bytes[0] = 9, throwsUnsupportedError);
    expect(cache.get('key'), [1, 2, 3]);
  });

  test('delete and clear update the byte budget', () {
    final cache = LruByteCache();
    cache.put('a', [1, 2]);
    cache.put('b', [3, 4]);
    cache.remove('a');
    expect(cache.length, 1);
    expect(cache.byteLength, 2);
    cache.clear();
    expect(cache.length, 0);
    expect(cache.byteLength, 0);
  });
}
