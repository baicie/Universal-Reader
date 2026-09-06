import 'dart:io';

void main(List<String> args) {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('lcov.info not found');
    exit(1);
  }

  final lines = file.readAsLinesSync();

  int totalFound = 0;
  int totalHit = 0;
  String? currentFile;
  int fileLines = 0;
  int fileHit = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      if (currentFile != null && fileLines > 0) {
        totalFound += fileLines;
        totalHit += fileHit;
      }
      currentFile = line.substring(3);
      fileLines = 0;
      fileHit = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final hit = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      fileLines++;
      if (hit > 0) fileHit++;
    } else if (line == 'end_of_record') {
      if (currentFile != null && fileLines > 0) {
        totalFound += fileLines;
        totalHit += fileHit;
      }
      currentFile = null;
    }
  }

  final pct = totalFound > 0 ? (totalHit / totalFound * 100).toStringAsFixed(1) : '0.0';
  print('Lines hit : $totalHit');
  print('Lines found: $totalFound');
  print('Coverage   : $pct%');
}
