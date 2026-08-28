import 'package:app/core/library_repository.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the library shell from a repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Universal Reader'), findsOneWidget);
    expect(find.text('全部书籍'), findsOneWidget);
    expect(find.text('阅读助手'), findsNothing);
  });

  testWidgets('settings expose a disabled reading assistant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('阅读助手'), findsOneWidget);
    expect(find.text('启用阅读助手'), findsOneWidget);
  });
}
