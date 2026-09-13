import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_notes.dart';
import 'package:app/features/reader/reader_notes_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReaderAnnotation _note({
  String id = 'note-1',
  String note = '',
  String quote = '',
  String locatorLabel = '',
  DateTime? createdAt,
}) {
  return ReaderAnnotation(
    id: id,
    note: note,
    quote: quote,
    locatorLabel: locatorLabel,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('ReaderNotesPane renders the empty label when no notes exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ReaderNotesPane(
          title: 'Notes',
          emptyLabel: 'NO_NOTES_YET',
          deleteLabel: 'DELETE',
          notes: const [],
          onOpen: (_) {},
          onDelete: (_) {},
        ),
      ),
    );

    expect(find.byKey(notesPanelKey), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('NO_NOTES_YET'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'ReaderNotesPane prefers the quote when present for noteListLabel',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderNotesPane(
            title: 'Notes',
            emptyLabel: 'NO_NOTES_YET',
            deleteLabel: 'DELETE',
            notes: [
              _note(
                id: 'a',
                quote: '  visible quote  ',
                note: 'body text',
                locatorLabel: 'locator-x',
              ),
            ],
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      );

      // quote is trimmed and takes priority over note body / locator.
      expect(find.text('visible quote'), findsOneWidget);
      expect(find.text('body text'), findsNothing);
      expect(find.text('locator-x'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    },
  );

  testWidgets(
    'ReaderNotesPane falls back to the note body when the quote is empty',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderNotesPane(
            title: 'Notes',
            emptyLabel: 'NO_NOTES_YET',
            deleteLabel: 'DELETE',
            notes: [_note(id: 'a', quote: '', note: '  explanation  ')],
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      );

      expect(find.text('explanation'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    },
  );

  testWidgets(
    'ReaderNotesPane falls back to the locator label when both quote and '
    'note are blank',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderNotesPane(
            title: 'Notes',
            emptyLabel: 'NO_NOTES_YET',
            deleteLabel: 'DELETE',
            notes: [_note(id: 'a', locatorLabel: 'p.42')],
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      );

      expect(find.text('p.42'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    },
  );

  testWidgets(
    'ReaderNotesPane renders multiple notes in order and exposes per-note '
    'delete keys',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderNotesPane(
            title: 'Notes',
            emptyLabel: 'NO_NOTES_YET',
            deleteLabel: 'DELETE',
            notes: [
              _note(id: 'first', quote: 'first quote'),
              _note(id: 'second', quote: 'second quote'),
            ],
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      );

      expect(find.text('first quote'), findsOneWidget);
      expect(find.text('second quote'), findsOneWidget);
      expect(find.byKey(const Key('delete-note-first')), findsOneWidget);
      expect(find.byKey(const Key('delete-note-second')), findsOneWidget);
      expect(find.text('NO_NOTES_YET'), findsNothing);
    },
  );

  testWidgets('ReaderNotesPane invokes onOpen with the tapped note', (
    tester,
  ) async {
    final tapped = <ReaderAnnotation>[];
    await tester.pumpWidget(
      _wrap(
        ReaderNotesPane(
          title: 'Notes',
          emptyLabel: 'NO_NOTES_YET',
          deleteLabel: 'DELETE',
          notes: [
            _note(id: 'alpha', quote: 'alpha quote'),
            _note(id: 'beta', quote: 'beta quote'),
          ],
          onOpen: tapped.add,
          onDelete: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('beta quote'));
    await tester.pumpAndSettle();

    expect(tapped, hasLength(1));
    expect(tapped.single.id, 'beta');
  });

  testWidgets('ReaderNotesPane invokes onDelete with the right note', (
    tester,
  ) async {
    final deleted = <ReaderAnnotation>[];
    await tester.pumpWidget(
      _wrap(
        ReaderNotesPane(
          title: 'Notes',
          emptyLabel: 'NO_NOTES_YET',
          deleteLabel: 'DELETE',
          notes: [
            _note(id: 'alpha', quote: 'alpha quote'),
            _note(id: 'beta', quote: 'beta quote'),
          ],
          onOpen: (_) {},
          onDelete: deleted.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-note-alpha')));
    await tester.pumpAndSettle();

    expect(deleted, hasLength(1));
    expect(deleted.single.id, 'alpha');
  });

  testWidgets(
    'ReaderNotesPane renders the delete tooltip for each IconButton',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderNotesPane(
            title: 'Notes',
            emptyLabel: 'NO_NOTES_YET',
            deleteLabel: 'DELETE_TOOLTIP',
            notes: [_note(id: 'a', quote: 'a quote')],
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'DELETE_TOOLTIP');
    },
  );

  // noteListLabel: quote/body/locator priority is the heart of the pane's
  // preview rendering; pin it directly here as a regression guard.
  group('noteListLabel', () {
    test('returns the trimmed quote when present', () {
      final label = noteListLabel(_note(quote: '  hello  '));
      expect(label, 'hello');
    });

    test('returns the trimmed body when the quote is empty', () {
      final label = noteListLabel(_note(note: '  body  '));
      expect(label, 'body');
    });

    test('returns the locator label as a last resort', () {
      final label = noteListLabel(
        _note(quote: '', note: '', locatorLabel: 'locator'),
      );
      expect(label, 'locator');
    });
  });
}
