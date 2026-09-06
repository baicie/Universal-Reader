import 'dart:io';

/// Usage: dart run tool/check_coverage.dart minPercent
/// Exits 0 if coverage meets threshold, else 1.
void main(List<String> args) {
  final minPct = args.isNotEmpty ? double.tryParse(args[0]) ?? 70.0 : 70.0;
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln('Error: coverage/lcov.info not found. Run tests with --coverage first.');
    exit(1);
  }

  int totalFound = 0;
  int totalHit = 0;

  for (final line in lcovFile.readAsLinesSync()) {
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final hit = int.tryParse(parts[1]) ?? 0;
        totalFound++;
        if (hit > 0) totalHit++;
      }
    }
  }

  if (totalFound == 0) {
    stderr.writeln('No coverage data found.');
    exit(1);
  }

  final pct = totalHit / totalFound * 100;
  final pass = pct >= minPct;
  final status = pass ? 'PASS' : 'FAIL';
  final icon = pass ? '✅' : '❌';

  print(
    '$icon Coverage: ${pct.toStringAsFixed(1)}%  '
    '($totalHit / $totalFound lines)  '
    '[threshold: $minPct%]  [$status]',
  );

  exit(pass ? 0 : 1);
}
