import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:app/features/library/shelf_ui.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _docId = 'shelf-ui-book';
const _otherId = 'shelf-ui-other';

LibraryDocument _buildDocument({
  String id = _docId,
  String title = 'Shelf UI Book',
  String author = 'Anonymous',
}) {
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: id,
      title: title,
      author: author,
      format: DocumentFormat.epub,
      type: DocumentType.reflow,
    ),
    readingState: ReadingState(progress: 0, lastOpened: DateTime(2026, 1, 1)),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget body,
  required LibraryRepository repository,
  ShelfRepository? shelfRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        if (shelfRepository != null)
          shelfRepositoryProvider.overrideWithValue(shelfRepository),
        aiSettingsRepositoryProvider.overrideWithValue(
          InMemoryAiSettingsRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  // let the controller finish its initial async load
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets(
    'FavoriteButton toggles the favorite state via the library provider',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      await _pump(
        tester,
        repository: repository,
        body: const FavoriteButton(documentId: _docId),
      );

      // Initially the book is not a favorite.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap to favorite.
      await tester.tap(find.byType(FavoriteButton));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // Tap again to unfavorite.
      await tester.tap(find.byType(FavoriteButton));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    },
  );

  testWidgets(
    'BookActionsButton opens a menu with edit, new-collection, and delete entries',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      await _pump(
        tester,
        repository: repository,
        body: const BookActionsButton(documentId: _docId),
      );

      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.editBookIdentity), findsOneWidget);
      expect(find.text(l10n.newCollection), findsOneWidget);
      expect(find.text(l10n.deleteFromLibrary), findsOneWidget);
    },
  );

  testWidgets(
    'BookActionsButton -> edit identity writes a new title and closes the dialog',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      await _pump(
        tester,
        repository: repository,
        body: const BookActionsButton(documentId: _docId),
      );

      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await tester.tap(find.text(l10n.editBookIdentity));
      await tester.pumpAndSettle();

      // The dialog uses fixed keys for the two text fields.
      final titleField = tester.widget<TextField>(
        find.byKey(const Key('edit-book-title')),
      );
      expect(titleField.controller!.text, 'Shelf UI Book');

      await tester.enterText(
        find.byKey(const Key('edit-book-title')),
        'New Title',
      );
      await tester.tap(find.text(l10n.saveAction));
      await tester.pumpAndSettle();

      // Re-open the dialog to verify the persisted title.
      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editBookIdentity));
      await tester.pumpAndSettle();
      final titleFieldAfter = tester.widget<TextField>(
        find.byKey(const Key('edit-book-title')),
      );
      expect(titleFieldAfter.controller!.text, 'New Title');

      // The dialog should be closable via cancel without crashing.
      await tester.tap(find.text(l10n.cancelAction));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-book-title')), findsNothing);
    },
  );

  testWidgets(
    'BookActionsButton -> delete shows a confirmation and canceling keeps the book',
    (tester) async {
      final repository = InMemoryLibraryRepository([
        _buildDocument(),
        _buildDocument(id: _otherId, title: 'Other Book'),
      ]);
      await _pump(
        tester,
        repository: repository,
        body: const BookActionsButton(documentId: _docId),
      );

      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await tester.tap(find.text(l10n.deleteFromLibrary));
      await tester.pumpAndSettle();

      expect(find.text(l10n.confirmDelete), findsOneWidget);
      expect(find.text(l10n.cancelAction), findsOneWidget);

      await tester.tap(find.text(l10n.cancelAction));
      await tester.pumpAndSettle();

      // The book is still in the repository after cancellation.
      final stored = await repository.load();
      expect(
        stored.any((d) => d.metadata.id == _docId),
        isTrue,
        reason: 'cancelling the confirm dialog must not delete the book',
      );
    },
  );

  testWidgets('confirmAndDeleteBook deletes the document when confirmed', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository([
      _buildDocument(),
      _buildDocument(id: _otherId, title: 'Other Book'),
    ]);
    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        aiSettingsRepositoryProvider.overrideWithValue(
          InMemoryAiSettingsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              // Eagerly watch the library provider so the controller finishes
              // loading before we tap into the dialog-driven actions below.
              ref.watch(libraryProvider);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => confirmAndDeleteBook(context, ref, _docId),
                  child: const Text('delete'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.confirmDelete), findsOneWidget);

    await tester.tap(find.text(l10n.confirmDelete));
    await tester.pumpAndSettle();

    final stored = await repository.load();
    expect(stored.any((d) => d.metadata.id == _docId), isFalse);
    expect(stored.any((d) => d.metadata.id == _otherId), isTrue);
  });

  testWidgets(
    'BookActionsButton -> new collection creates a collection and adds the book',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      final shelves = InMemoryShelfRepository();
      await _pump(
        tester,
        repository: repository,
        shelfRepository: shelves,
        body: const BookActionsButton(documentId: _docId),
      );

      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await tester.tap(find.text(l10n.newCollection));
      await tester.pumpAndSettle();

      // The new-collection dialog has a single TextField; type a name and submit.
      await tester.enterText(find.byType(TextField), 'Travel');
      await tester.tap(find.text(l10n.createCollection));
      await tester.pumpAndSettle();

      final stored = await shelves.load();
      expect(stored.collections.length, 1);
      expect(stored.collections.first.name, 'Travel');
      expect(stored.collections.first.contains(_docId), isTrue);
    },
  );

  testWidgets(
    'showCreateCollectionDialog rejects an empty name and does not create a shelf',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      final shelves = InMemoryShelfRepository();
      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          shelfRepositoryProvider.overrideWithValue(shelves),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(libraryProvider);
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showCreateCollectionDialog(context, ref),
                    child: const Text('new'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('new'));
      await tester.pumpAndSettle();

      // Submit without typing anything.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await tester.tap(find.text(l10n.createCollection));
      await tester.pumpAndSettle();

      final stored = await shelves.load();
      expect(stored.collections, isEmpty);

      // The dialog should still be open after rejection.
      expect(find.text(l10n.createCollection), findsOneWidget);
    },
  );

  testWidgets(
    'BookActionsButton toggles an existing collection membership from the menu',
    (tester) async {
      final repository = InMemoryLibraryRepository([_buildDocument()]);
      const seed = LibraryShelves(
        favoriteIds: <String>{},
        collections: [
          LibraryCollection(
            id: 'travel',
            name: 'Travel',
            color: 0xFFC69355,
            documentIds: [],
          ),
        ],
      );
      final shelves = InMemoryShelfRepository();
      await shelves.save(seed);

      await _pump(
        tester,
        repository: repository,
        shelfRepository: shelves,
        body: const BookActionsButton(documentId: _docId),
      );

      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.addToNamedCollection('Travel')), findsOneWidget);

      // Toggle on.
      await tester.tap(find.text(l10n.addToNamedCollection('Travel')));
      await tester.pumpAndSettle();
      var stored = await shelves.load();
      expect(stored.collections.first.contains(_docId), isTrue);

      // Toggle off via the same menu.
      await tester.tap(find.byType(BookActionsButton));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.removeFromNamedCollection('Travel')),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.removeFromNamedCollection('Travel')));
      await tester.pumpAndSettle();
      stored = await shelves.load();
      expect(stored.collections.first.contains(_docId), isFalse);
    },
  );

  testWidgets(
    'confirmAndDeleteBook is a no-op when the document id is unknown',
    (tester) async {
      final repository = InMemoryLibraryRepository([
        _buildDocument(id: _otherId, title: 'Other Book'),
      ]);
      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(libraryProvider);
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        confirmAndDeleteBook(context, ref, 'unknown-id'),
                    child: const Text('delete'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();

      // No dialog should appear, the other book stays.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.confirmDelete), findsNothing);
      final stored = await repository.load();
      expect(stored.any((d) => d.metadata.id == _otherId), isTrue);
    },
  );
}
