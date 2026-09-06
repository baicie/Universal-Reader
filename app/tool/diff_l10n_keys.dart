import 'dart:io';

void main() {
  final enText = File('lib/l10n/app_en.arb').readAsStringSync();
  final zhText = File('lib/l10n/app_zh.arb').readAsStringSync();

  final keyPattern = RegExp(r'"([a-zA-Z][a-zA-Z0-9_]+)"\s*:');
  final enKeys = keyPattern.allMatches(enText).map((m) => m.group(1)).toSet();
  final zhKeys = keyPattern.allMatches(zhText).map((m) => m.group(1)).toSet();

  final onlyEn = enKeys.difference(zhKeys);
  final onlyZh = zhKeys.difference(enKeys);

  print('Only in en (${onlyEn.length}):');
  for (final k in onlyEn) print('  $k');
  print('');
  print('Only in zh (${onlyZh.length}):');
  for (final k in onlyZh) print('  $k');
}
