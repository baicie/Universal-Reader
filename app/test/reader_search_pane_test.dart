import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/reader/reader_search_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hint = 'SEARCH_HINT';
const _title = 'Search';
const _emptyLabel = 'NO_HITS';
const _query = 'mars';

SearchResult _hit({required String excerpt, required Locator locator}) {
  return SearchResult(title: 'Chapter $excerpt', excerpt: excerpt, locator: locator);
}

final _textLocator = const TextLocator(offset: 5);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('ReaderSearchPane renders title, hint and field with empty state',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: '',
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.byKey(searchPanelKey), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(readerSearchFieldKey));
    expect(field.decoration?.hintText, _hint);
    // The field starts empty, so the empty-label must not appear yet.
    expect(find.text(_emptyLabel), findsNothing);
  });

  testWidgets('ReaderSearchPane shows the empty label when there are no hits',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: _query,
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.text(_emptyLabel), findsOneWidget);
    expect(find.byKey(const Key('search-hit-0')), findsNothing);
  });

  testWidgets(
      'ReaderSearchPane does not show the empty label when query is blank, '
      'even with no hits', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: '   ',
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.text(_emptyLabel), findsNothing);
  });

  testWidgets('ReaderSearchPane renders one entry per hit with stable keys',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: _query,
          hits: [
            _hit(excerpt: 'first excerpt', locator: _textLocator),
            _hit(excerpt: 'second excerpt', locator: _textLocator),
            _hit(excerpt: 'third excerpt', locator: _textLocator),
          ],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('search-hit-0')), findsOneWidget);
    expect(find.byKey(const Key('search-hit-1')), findsOneWidget);
    expect(find.byKey(const Key('search-hit-2')), findsOneWidget);
    expect(find.text('first excerpt'), findsOneWidget);
    expect(find.text('second excerpt'), findsOneWidget);
    expect(find.text('third excerpt'), findsOneWidget);
    expect(find.text(_emptyLabel), findsNothing);
  });

  testWidgets('ReaderSearchPane invokes onQuery when the field text changes',
      (tester) async {
    final observed = <String>[];
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: '',
          hits: const [],
          onQuery: observed.add,
          onOpen: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(readerSearchFieldKey), 'martian');
    await tester.pumpAndSettle();

    expect(observed, contains('martian'));
  });

  testWidgets(
      'ReaderSearchPane invokes onOpen with the hit whose excerpt was tapped',
      (tester) async {
    final hits = [
      _hit(excerpt: 'first excerpt', locator: _textLocator),
      _hit(excerpt: 'second excerpt', locator: _textLocator),
    ];
    final opened = <SearchResult>[];
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: _query,
          hits: hits,
          onQuery: (_) {},
          onOpen: opened.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('search-hit-1')));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.excerpt, 'second excerpt');
  });

  testWidgets(
      'ReaderSearchPane syncs its TextEditingController to widget.query '
      'when the parent updates the query', (tester) async {
    Widget build(String query) {
      return _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: query,
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      );
    }

    await tester.pumpWidget(build('initial'));
    final initialController = tester
        .widget<TextField>(find.byKey(readerSearchFieldKey))
        .controller!;
    expect(initialController.text, 'initial');

    // User edits the field; the parent still hasn't heard about it.
    await tester.enterText(find.byKey(readerSearchFieldKey), 'user-typed');
    await tester.pumpAndSettle();
    expect(initialController.text, 'user-typed');

    // Parent supplies a new authoritative query — controller must follow it.
    await tester.pumpWidget(build('from-parent'));
    final newController = tester
        .widget<TextField>(find.byKey(readerSearchFieldKey))
        .controller!;
    expect(identical(newController, initialController), isTrue,
        reason: 'controller identity must be stable across updates');
    expect(newController.text, 'from-parent');
    expect(newController.selection.isCollapsed, isTrue);
    expect(newController.selection.baseOffset, 'from-parent'.length);
  });

  testWidgets(
      'ReaderSearchPane keeps the user-supplied cursor position when the '
      'parent re-supplies the same query (no didUpdateWidget cursor reset)',
      (tester) async {
    Widget build(String query) {
      return _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: query,
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      );
    }

    await tester.pumpWidget(build('initial'));
    final controller = tester
        .widget<TextField>(find.byKey(readerSearchFieldKey))
        .controller!;
    expect(controller.text, 'initial');

    // Simulate the user placing their cursor mid-string; then the parent
    // rebuilds with the same query (e.g. on a rebuild triggered by an
    // unrelated state change). The pane must NOT clobber the cursor.
    controller.value = const TextEditingValue(
      text: 'initial',
      selection: TextSelection.collapsed(offset: 4),
    );

    await tester.pumpWidget(build('initial'));
    final sameController = tester
        .widget<TextField>(find.byKey(readerSearchFieldKey))
        .controller!;
    expect(identical(sameController, controller), isTrue);
    expect(sameController.text, 'initial');
    expect(sameController.selection.baseOffset, 4,
        reason: 'cursor must not be reset when query is unchanged');
  });

  testWidgets(
      'ReaderSearchPane snaps the cursor to the end when the parent '
      'updates the query to a different value', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: 'old',
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    final controller = tester
        .widget<TextField>(find.byKey(readerSearchFieldKey))
        .controller!;

    await tester.pumpWidget(
      _wrap(
        ReaderSearchPane(
          title: _title,
          hint: _hint,
          emptyLabel: _emptyLabel,
          query: 'newer',
          hits: const [],
          onQuery: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(controller.text, 'newer');
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, 'newer'.length);
  });
}
