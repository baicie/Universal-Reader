import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_ai_panel.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationTurn>> load(String documentId) async {
    throw const FormatException('corrupt conversation');
  }

  @override
  Future<void> save(String documentId, List<ConversationTurn> turns) async {}
}

void main() {
  testWidgets(
    'conversation load failure is shown instead of an empty history',
    (tester) async {
      final document = SampleReaderDocument(
        metadata: const DocumentMetadata(
          id: 'design',
          title: '设计中的设计',
          author: '原研哉',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRuntimeProvider.overrideWithValue(
              AiRuntime(
                useGateway: false,
                baseUrl: '',
                serverHasKey: false,
                conversations: _FailingConversationRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReaderAiPanel(
              document: document,
              settings: const AiSettings(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('无法读取问答记录。'), findsOneWidget);
      expect(find.text('问答记录'), findsNothing);
    },
  );
}
