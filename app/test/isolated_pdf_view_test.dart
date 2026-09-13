import 'package:app/core/models.dart';
import 'package:app/core/pdf_document.dart';
import 'package:app/features/reader/renderers/isolated_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'pdf-1',
    title: 'PDF Book',
    author: '',
    format: DocumentFormat.pdf,
    type: DocumentType.fixedPage,
  );

  List<int> buildBytes() =>
      minimalPdfBytes(pages: ['page one text', 'page two text']);

  PdfReaderDocument buildDocument() {
    return PdfReaderDocument.parse(metadata: metadata, bytes: buildBytes());
  }

  Widget host(IsolatedPdfView view) {
    return MaterialApp(home: Scaffold(body: view));
  }

  // ── fallback branch ────────────────────────────────────────────────────

  testWidgets(
    'renders the fallback path when the native renderer is unavailable',
    (tester) async {
      final document = buildDocument();
      const fallback = Text('fallback body');

      await tester.pumpWidget(
        host(
          IsolatedPdfView(
            document: document,
            bytes: buildBytes(),
            fallback: fallback,
            zoom: 1.0,
          ),
        ),
      );

      expect(find.byKey(const Key('pdf-surface')), findsOneWidget);
      expect(find.byKey(const Key('pdf-zoom')), findsOneWidget);
      expect(find.text('fallback body'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the fallback path when bytes are null even if native renderer is on',
    (tester) async {
      final document = buildDocument();
      const fallback = Text('missing bytes fallback');

      await tester.pumpWidget(
        host(
          IsolatedPdfView(
            document: document,
            bytes: null,
            fallback: fallback,
            zoom: 1.0,
          ),
        ),
      );

      expect(find.byKey(const Key('pdf-surface')), findsOneWidget);
      expect(find.byKey(const Key('pdf-zoom')), findsOneWidget);
      expect(find.text('missing bytes fallback'), findsOneWidget);
    },
  );

  testWidgets('renders the fallback path when bytes are empty', (tester) async {
    final document = buildDocument();
    const fallback = Text('empty bytes fallback');

    await tester.pumpWidget(
      host(
        IsolatedPdfView(
          document: document,
          bytes: const <int>[],
          fallback: fallback,
          zoom: 1.0,
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-surface')), findsOneWidget);
    expect(find.text('empty bytes fallback'), findsOneWidget);
  });

  testWidgets('applies zoom to the Transform.scale widget', (tester) async {
    final document = buildDocument();
    const fallback = Text('zoom target');

    await tester.pumpWidget(
      host(
        IsolatedPdfView(
          document: document,
          bytes: buildBytes(),
          fallback: fallback,
          zoom: 1.5,
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-zoom')), findsOneWidget);
    expect(find.text('zoom target'), findsOneWidget);
  });

  testWidgets('does not crash when didUpdateWidget changes the zoom', (
    tester,
  ) async {
    final document = buildDocument();
    const fallback = Text('zoom widget test');

    Widget build(double zoom) => host(
      IsolatedPdfView(
        document: document,
        bytes: buildBytes(),
        fallback: fallback,
        zoom: zoom,
      ),
    );

    await tester.pumpWidget(build(1.0));
    await tester.pumpWidget(build(2.0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pdf-surface')), findsOneWidget);
  });
}
