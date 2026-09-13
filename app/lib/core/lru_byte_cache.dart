import 'dart:collection';

class LruByteCache {
  LruByteCache({
    this.maxEntries = 128,
    this.maxBytes = 16 * 1024 * 1024,
    this.maxEntryBytes = 4 * 1024 * 1024,
  }) : assert(maxEntries > 0),
       assert(maxBytes > 0),
       assert(maxEntryBytes > 0);

  final int maxEntries;
  final int maxBytes;
  final int maxEntryBytes;
  final LinkedHashMap<String, List<int>> _values = LinkedHashMap();
  int _bytes = 0;

  int get length => _values.length;
  int get byteLength => _bytes;

  List<int>? get(String key) {
    final value = _values.remove(key);
    if (value == null) return null;
    _values[key] = value;
    return List<int>.unmodifiable(value);
  }

  void put(String key, List<int> value) {
    if (key.isEmpty || value.isEmpty || value.length > maxEntryBytes) return;
    final previous = _values.remove(key);
    if (previous != null) _bytes -= previous.length;
    _values[key] = List<int>.from(value);
    _bytes += value.length;
    while (_values.length > maxEntries || _bytes > maxBytes) {
      final oldest = _values.keys.first;
      final removed = _values.remove(oldest);
      if (removed != null) _bytes -= removed.length;
    }
  }

  List<int>? remove(String key) {
    final removed = _values.remove(key);
    if (removed == null) return null;
    _bytes -= removed.length;
    return removed;
  }

  void clear() {
    _values.clear();
    _bytes = 0;
  }
}
