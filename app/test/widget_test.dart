import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/library_repository.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('renders the library shell from a repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Universal Reader'), findsOneWidget);
    expect(find.text('全部书籍'), findsOneWidget);
  });
}
