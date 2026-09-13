import 'package:app/core/library_controller.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _documentCount = 10000;

LibraryDocument _scaleDocument(int index) {
  final comic = index % 5 == 0;
  final progress = index % 17 == 0 ? 0.45 : 0.0;
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: 'book-${index.toString().padLeft(5, '0')}',
      title: 'Book ${index.toString().padLeft(5, '0')}',
      author: 'Author ${index % 200}',
      format: comic ? DocumentFormat.cbz : DocumentFormat.epub,
      type: comic ? DocumentType.comic : DocumentType.reflow,
      coverColor: 0xFF527882,
      contentHash: 'hash-$index',
    ),
    readingState: ReadingState(
      progress: progress,
      lastOpened: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
    ),
  );
}

void main() {
  test(
    'ten thousand documents stay searchable, filterable, and sortable',
    () async {
      final documents = List.generate(_documentCount, _scaleDocument);
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(documents),
      );
      final stopwatch = Stopwatch()..start();

      await controller.load();
      expect(controller.documents, hasLength(_documentCount));
      final firstView = controller.documents;
      expect(identical(controller.documents, firstView), isTrue);

      controller.search('Book 09999');
      expect(identical(controller.documents, firstView), isFalse);
      expect(controller.documents.single.metadata.id, 'book-09999');

      controller.search('');
      controller.selectType('comic');
      expect(controller.documents, hasLength(_documentCount ~/ 5));

      controller.selectType('all');
      controller.selectSort('title');
      expect(controller.documents.first.metadata.id, 'book-00000');
      expect(controller.documents.last.metadata.id, 'book-09999');

      controller.selectSort('progress');
      expect(controller.documents.first.readingState.progress, 0.45);

      await controller.updateProgress('book-05000', 0.8);
      expect(controller.documentById('book-05000')?.readingState.progress, 0.8);
      expect(controller.continueReading, isNotNull);

      stopwatch.stop();
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 8)),
        reason: '10k library operations took ${stopwatch.elapsed}',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
