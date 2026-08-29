import 'dart:convert';

/// Minimal uncompressed PDF with one text string per page.
List<int> minimalPdfBytes({List<String> pages = const ['hello from pdf']}) {
  final objects = <String>['1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'];
  final kids = [for (var i = 0; i < pages.length; i++) '${3 + i * 2} 0 R']
      .join(' ');
  objects.add(
    '2 0 obj << /Type /Pages /Kids [$kids] /Count ${pages.length} >> endobj',
  );
  for (var i = 0; i < pages.length; i++) {
    final pageObj = 3 + i * 2;
    final contentObj = pageObj + 1;
    final text = pages[i].replaceAll('(', '\\(').replaceAll(')', '\\)');
    final stream = 'BT /F1 12 Tf 72 720 Td ($text) Tj ET';
    objects.add(
      '$pageObj 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
      '/Contents $contentObj 0 R /Resources << /Font << /F1 ${3 + pages.length * 2} 0 R >> >> >> endobj',
    );
    objects.add(
      '$contentObj 0 obj << /Length ${stream.length} >> stream\n$stream\nendstream endobj',
    );
  }
  final fontObj = 3 + pages.length * 2;
  objects.add(
    '$fontObj 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
  );

  final buffer = StringBuffer('%PDF-1.1\n');
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.writeln(object);
  }
  final xrefAt = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 ${objects.length + 1}');
  buffer.writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    buffer.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }
  buffer.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
  buffer.writeln('startxref');
  buffer.writeln(xrefAt);
  buffer.write('%%EOF');
  return utf8.encode(buffer.toString());
}
