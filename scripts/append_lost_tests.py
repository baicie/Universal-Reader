#!/usr/bin/env python3
"""Append the 10 missing tests (step 98 of transcript) into the current
UTF-8 / CRLF library_controller_test.dart, preserving the existing encoding."""
import sys
from pathlib import Path

OUT = Path(r"D:/workspace/git-code/Universal-Reader/app/test/library_controller_test.dart")

ADD = """
  group('deleteCollection', () {
    test('removes the collection from the shelf', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(
        repository: repository,
      );
      await controller.load();
      final created = await controller.createCollection('shelf-A');
      expect(created, isNotNull);

      await controller.deleteCollection(created!.id);

      expect(controller.collections, isEmpty);
      expect(controller.isInCollection(created.id, 'design'), isFalse);
      expect(controller.collectionName('collection:${created.id}'), isNull);
    });

    test('falls back to all when the active section is removed', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(
        repository: repository,
      );
      await controller.load();
      final created = await controller.createCollection('shelf-A');
      controller.selectSection('collection:${created!.id}');
      expect(controller.section, 'collection:${created.id}');

      await controller.deleteCollection(created.id);

      expect(controller.section, 'all');
    });

    test('leaves other sections alone when an unrelated collection is removed',
        () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(
        repository: repository,
      );
      await controller.load();
      final keep = await controller.createCollection('shelf-A');
      final drop = await controller.createCollection('shelf-B');
      controller.selectSection('favorites');

      await controller.deleteCollection(drop!.id);

      expect(controller.section, 'favorites');
      expect(
        controller.collections.map((c) => c.name),
        containsAll(['shelf-A']),
        reason: 'unrelated collection must survive',
      );
      expect(controller.isInCollection(keep!.id, 'design'), isFalse);
    });

    test('is a no-op when the collection id is unknown', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(
        repository: repository,
      );
      await controller.load();
      final before = controller.collections;

      await controller.deleteCollection('c-does-not-exist');

      expect(controller.collections, before);
    });
  });

  group('waitUntilReady', () {
    test('resolves once load finishes and is a no-op afterwards', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      expect(controller.loading, isTrue);

      final firstWait = controller.waitUntilReady();
      final secondWait = controller.waitUntilReady();
      await controller.load();

      await Future.wait([firstWait, secondWait]);
      expect(controller.loading, isFalse);

      final third = controller.waitUntilReady();
      await third;
      expect(controller.loading, isFalse);
    });

    test('does not keep listeners around after load', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      final initialListeners = controller.hasListeners;

      final pending = controller.waitUntilReady();
      expect(controller.hasListeners, isTrue);
      await controller.load();
      await pending;
      expect(controller.hasListeners, initialListeners);
    });

    test('returns a completed future when load already finished', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();
      expect(controller.loading, isFalse);

      final pending = controller.waitUntilReady();
      // Synchronously resolved: the returned future should already be done
      // before we even hand it to the event loop.
      final completed = await pending.timeout(
        const Duration(milliseconds: 1),
      );
      expect(completed, isNull);
    });
  });

  group('search refresh', () {
    test('empty query skips the async scan and waitForSearch resolves', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: _ThrowingAnnotationRepository(),
      );
      await controller.load();

      controller.search('');
      // The throwing repo must not be reached; waitForSearch must not hang.
      await controller.waitForSearch();
      expect(controller.documents, isEmpty);
    });

    test('a stale pending search does not publish after a newer query', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: _StubAnnotationRepository(const {}),
      );
      await controller.load();
      controller.addDocumentForTest(
        _stubDoc(id: 'design', title: 'Design Notes'),
      );

      controller.search('design');
      controller.search('rust');
      await controller.waitForSearch();

      expect(
        controller.documents.where((d) => d.metadata.id == 'design'),
        isEmpty,
        reason: 'the stale design hit must be discarded by the new query',
      );
      expect(
        controller.documents.where((d) => d.metadata.id == 'rust'),
        isEmpty,
        reason: 'no metadata match for rust either',
      );
    });

    test('waitForSearch resolves when annotation store throws', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: _ThrowingAnnotationRepository(),
      );
      await controller.load();
      controller.addDocumentForTest(
        _stubDoc(id: 'design', title: 'Design Notes'),
      );

      controller.search('design');
      await controller.waitForSearch();

      expect(
        controller.documents.where((d) => d.metadata.id == 'design'),
        hasLength(1),
      );
    });
  });
"""
# Note: ADD ends with closing brace of main, but we want it before the final closing brace.

b = OUT.read_bytes()
text = b.decode("utf-8")
# Normalize line endings to LF for the search/replace logic.
text_lf = text.replace("\r\n", "\n")

ANCHOR_LF = "      controller.search('needle');\n      await controller.waitForSearch();\n\n      expect(controller.documents, isEmpty);\n    });\n  });\n}\n"

if ANCHOR_LF not in text_lf:
    print("ANCHOR NOT FOUND")
    print("tail repr:", repr(text_lf[-200:]))
    sys.exit(1)

# ADD must end with just the inner close of the annotation-backed search group,
# so we close the three new groups but not the outer `void main()`.
ADD_LF = ADD.lstrip("\n")
# Strip the trailing `}` that would close main; main is still closed by ANCHOR's last `}`.
ADD_LF = ADD_LF.rstrip("\n")
# We need to remove the final closing `}` from ADD because we want the original
# `}` (closing main) to remain after our new groups.
# Simpler: remove the final `}` + newline from ADD.
ADD_LF = ADD_LF.rstrip()
if ADD_LF.endswith("}"):
    ADD_LF = ADD_LF[:-1].rstrip()

# Insert ADD_LF before the final `}` (which closes main).
new_text_lf = text_lf.replace(
    ANCHOR_LF,
    ANCHOR_LF + "\n" + ADD_LF + "\n",
    1,
)
# Re-emit with CRLF to match existing style.
new_text = new_text_lf.replace("\n", "\r\n")
OUT.write_bytes(new_text.encode("utf-8"))
print(f"wrote {len(new_text)} chars (was {len(text)})")
