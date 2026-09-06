import 'dart:io';

/// Reports lines with 0 hits per file to spot coverage gaps.
void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('lcov.info not found');
    exit(1);
  }

  String? currentFile;
  int fileFound = 0;
  int fileHit = 0;
  final List<MapEntry<String, double>> results = [];

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      if (currentFile != null && fileFound > 0) {
        final pct = fileHit / fileFound * 100;
        results.add(MapEntry(currentFile, pct));
      }
      currentFile = line.substring(3);
      fileFound = 0;
      fileHit = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final hit = int.tryParse(parts[1]) ?? 0;
        fileFound++;
        if (hit > 0) fileHit++;
      }
    }
  }
  if (currentFile != null && fileFound > 0) {
    final pct = fileHit / fileFound * 100;
    results.add(MapEntry(currentFile, pct));
  }

  // Show only files under 90% sorted by lowest coverage.
  final weak = results.where((e) => e.value < 90).toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final e in weak.take(20)) {
    print('${e.value.toStringAsFixed(1).padLeft(5)}%  ${e.key}');
  }
}
