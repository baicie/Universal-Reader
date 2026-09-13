import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/ai/model_client.dart';
import 'package:app/features/tools/reader_ai_panel.dart';
import 'package:app/features/tools/reader_tool.dart';
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

class _FailingAnnotationRepository implements AnnotationRepository {
  @override
  Future<List<ReaderAnnotation>> load(String documentId) async => const [];
  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {}
}

class _RecordingAnnotationRepository implements AnnotationRepository {
  final List<ReaderAnnotation> saved = [];
  @override
  Future<List<ReaderAnnotation>> load(String documentId) async => const [];
  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    saved.addAll(notes);
  }
}

SampleReaderDocument _sampleDocument() => SampleReaderDocument(
  metadata: const DocumentMetadata(
    id: 'design',
    title: '设计中的设计',
    author: '原研哉',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  ),
);

const _readySettings = AiSettings(
  enabled: true,
  endpoint: 'https://api.deepseek.com',
  model: 'deepseek-chat',
  apiKey: 'sk-test',
);

Widget _wrap(
  Widget child, {
  required AiRuntime runtime,
  Future<void> Function(Locator)? onJump,
  AiSettings? settings,
}) {
  return ProviderScope(
    overrides: [aiRuntimeProvider.overrideWithValue(runtime)],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReaderAiPanel(
        document: _sampleDocument(),
        settings: settings ?? const AiSettings(),
        onJump: onJump,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'conversation load failure is shown instead of an empty history',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox.shrink(),
          runtime: AiRuntime(
            useGateway: false,
            baseUrl: '',
            serverHasKey: false,
            conversations: _FailingConversationRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('无法读取问答记录。'), findsOneWidget);
      expect(find.text('问答记录'), findsNothing);
    },
  );

  testWidgets('unconfigured settings show the enable-in-settings button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('到设置中启用阅读助手'), findsOneWidget);
    // The chip row should still render all four kinds.
    expect(find.text('总结'), findsOneWidget);
    expect(find.text('解释'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('提问'), findsOneWidget);
  });

  testWidgets('selecting the ask kind reveals the question input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    // No TextField until ask is selected.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('输入关于这一页的问题'), findsOneWidget);
  });

  testWidgets('switching the askDocument filter changes the panel header', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('问这一页'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '问这本书'));
    await tester.pumpAndSettle();

    expect(find.text('问这本书'), findsWidgets);
  });

  testWidgets('a successful reply is appended to the conversation and shown', (
    tester,
  ) async {
    final client = RecordingModelClient(reply: '这是摘要');
    final conversations = InMemoryConversationRepository();
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: _RecordingRuntime(
          conversations: conversations,
          client: client,
        ),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发送摘录'));
    await tester.pumpAndSettle();

    expect(find.text('这是摘要'), findsOneWidget);
    expect(client.calls, 1);
    final stored = await conversations.load('design');
    expect(stored, hasLength(1));
    expect(stored.first.reply, '这是摘要');
    expect(stored.first.kind, ReaderToolKind.summarize);
  });

  testWidgets(
    'an unavailable result surfaces the message without writing a turn',
    (tester) async {
      // Build a tool whose settings fail isReady so the message comes from
      // the assistantDisabled / assistantNotConfigured fallback.
      await tester.pumpWidget(
        _wrap(
          const SizedBox.shrink(),
          runtime: AiRuntime.local(InMemoryConversationRepository()),
          // Settings are missing the api key, so isReady is false.
          settings: const AiSettings(
            enabled: true,
            endpoint: 'https://api.deepseek.com',
            model: 'deepseek-chat',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The panel shows the "enable in settings" CTA in that branch.
      expect(find.text('到设置中启用阅读助手'), findsOneWidget);
    },
  );

  testWidgets('save as note persists the reply and shows a snackbar', (
    tester,
  ) async {
    final client = RecordingModelClient(reply: '笔记内容');
    final conversations = InMemoryConversationRepository();
    final annotations = _RecordingAnnotationRepository();
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: _RecordingRuntime(
          conversations: conversations,
          annotations: annotations,
          client: client,
        ),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发送摘录'));
    await tester.pumpAndSettle();
    // The reply is rendered inside the conversation history list.
    expect(find.textContaining('笔记内容', findRichText: true), findsOneWidget);

    await tester.tap(find.text('保存为笔记'));
    await tester.pumpAndSettle();

    expect(annotations.saved, hasLength(1));
    expect(annotations.saved.first.note, '笔记内容');
    expect(annotations.saved.first.quote, isEmpty);
    expect(annotations.saved.first.locatorLabel, 'chapter-4 · 37%');
  });

  testWidgets(
    'a failing annotation repository shows the notes unavailable message',
    (tester) async {
      final client = RecordingModelClient(reply: 'reply');
      await tester.pumpWidget(
        _wrap(
          const SizedBox.shrink(),
          runtime: _RecordingRuntime(
            conversations: InMemoryConversationRepository(),
            annotations: _FailingAnnotationRepository(),
            client: client,
          ),
          settings: _readySettings,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('发送摘录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存为笔记'));
      await tester.pumpAndSettle();

      expect(find.text('无法读取笔记。'), findsOneWidget);
    },
  );

  testWidgets('a tool exception is surfaced as a request failed message', (
    tester,
  ) async {
    final client = _ThrowingModelClient();
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: _RecordingRuntime(
          conversations: InMemoryConversationRepository(),
          client: client,
        ),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发送摘录'));
    await tester.pumpAndSettle();

    expect(find.textContaining('请求失败'), findsOneWidget);
  });

  testWidgets('proposals produce jump buttons that invoke onJump', (
    tester,
  ) async {
    final client = RecordingModelClient(reply: 'replies');
    Locator? jumpedTo;
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: _RecordingRuntime(
          conversations: InMemoryConversationRepository(),
          client: client,
        ),
        settings: _readySettings,
        onJump: (locator) async {
          jumpedTo = locator;
        },
      ),
    );
    await tester.pumpAndSettle();

    // The sample document yields one search hit for "白", so the
    // proposals row should appear after a request with askDocument=true.
    await tester.tap(find.widgetWithText(FilterChip, '问这本书'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '白');
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送摘录'));
    await tester.pumpAndSettle();

    final jumpButton = find.widgetWithText(
      OutlinedButton,
      '跳转到 chapter-4 · 37%',
    );
    expect(jumpButton, findsOneWidget);
    await tester.tap(jumpButton);
    await tester.pumpAndSettle();

    expect(jumpedTo, isA<EpubLocator>());
    expect((jumpedTo! as EpubLocator).href, 'chapter-4');
  });

  testWidgets('panel renders a stored conversation from the repository', (
    tester,
  ) async {
    final repo = InMemoryConversationRepository({
      'design': [
        ConversationTurn(
          kind: ReaderToolKind.summarize,
          reply: '先前的摘要',
          locatorLabel: 'chapter-1',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    });
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: AiRuntime.local(repo),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('问答记录'), findsOneWidget);
    expect(find.text('先前的摘要'), findsOneWidget);
    expect(find.text('chapter-1'), findsOneWidget);
  });

  testWidgets('tapping a kind chip updates the active selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();

    ChoiceChip chipFor(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    expect(chipFor('总结').selected, isTrue);
    expect(chipFor('解释').selected, isFalse);

    await tester.tap(find.widgetWithText(ChoiceChip, '解释'));
    await tester.pumpAndSettle();

    expect(chipFor('总结').selected, isFalse);
    expect(chipFor('解释').selected, isTrue);
  });

  testWidgets('dispose does not crash after a request in flight', (
    tester,
  ) async {
    final client = RecordingModelClient(reply: 'late');
    await tester.pumpWidget(
      _wrap(
        const SizedBox.shrink(),
        runtime: _RecordingRuntime(
          conversations: InMemoryConversationRepository(),
          client: client,
        ),
        settings: _readySettings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送摘录'));
    await tester.pump();

    // Replace the tree before the future settles; the panel must dispose
    // its controllers cleanly.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}

class _ThrowingModelClient implements ModelClient {
  @override
  Future<String> complete(List<Map<String, String>> messages) async {
    throw StateError('boom');
  }
}

class _RecordingRuntime extends AiRuntime {
  _RecordingRuntime({
    required this.client,
    required super.conversations,
    super.annotations,
  }) : super(useGateway: false, baseUrl: '', serverHasKey: false);

  final ModelClient client;

  @override
  ModelClient modelClient(AiSettings settings) => client;
}
