import 'package:app/core/comic_document.dart';
import 'package:app/core/comic_layout.dart';
import 'package:app/core/models.dart';
import 'package:app/features/reader/renderers/isolated_comic_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'comic-1',
    title: 'Pages',
    author: 'A',
    format: DocumentFormat.cbz,
    type: DocumentType.comic,
  );

  // ── double-page layout branches ─────────────────────────────────────────

  testWidgets('double-page shows left+right images side by side', (tester) async {
    final document = ComicReaderDocument.parse(
      metadata: metadata,
      bytes: zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IsolatedComicView(
            document: document,
            layout: ComicLayout.double,
            direction: ComicReadDirection.ltr,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('comic-page-left')), findsOneWidget);
    expect(find.byKey(const Key('comic-page-right')), findsOneWidget);
    expect(find.byKey(const Key('comic-page')), findsNothing);
  });

  testWidgets('double-page LTR shows single left image when right page is absent', (tester) async {
    // Single-page comic with double layout: comicSpread returns right = null.
    final document = ComicReaderDocument.parse(
      metadata: metadata,
      bytes: zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IsolatedComicView(
            document: document,
            layout: ComicLayout.double,
            direction: ComicReadDirection.ltr,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('comic-page-left')), findsOneWidget);
    expect(find.byKey(const Key('comic-page-right')), findsNothing);
  });

  testWidgets('double-page RTL shows single right image when left page is absent', (tester) async {
    // RTL direction swaps left/right: with a single page, left = null, right = non-null.
    final document = ComicReaderDocument.parse(
      metadata: metadata,
      bytes: zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IsolatedComicView(
            document: document,
            layout: ComicLayout.double,
            direction: ComicReadDirection.rtl,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('comic-page-right')), findsOneWidget);
    expect(find.byKey(const Key('comic-page-left')), findsNothing);
  });
}
