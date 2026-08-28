import 'package:app/core/library_controller.dart';
import 'package:app/core/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waitUntilReady completes after load and is later a no-op', () async {
    final controller = PersistedLibraryController(
      repository: InMemoryLibraryRepository(),
      initialDocuments: const [],
    );

    final pending = controller.waitUntilReady();
    await controller.load();
    await pending;
    expect(controller.loading, isFalse);

    await controller.waitUntilReady();
    expect(controller.loading, isFalse);
  });
}
