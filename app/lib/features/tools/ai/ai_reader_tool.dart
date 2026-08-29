import '../../../core/reader_runtime.dart';
import '../../../l10n/l10n.dart';
import '../reader_tool.dart';
import 'ai_settings.dart';
import 'grounding.dart';
import 'model_client.dart';
import 'prompts.dart';

class AiReaderTool implements ReaderTool {
  AiReaderTool({
    required this.settings,
    this.grounding = const DocumentGrounding(),
    this.prompts = const ReaderPrompts(),
    this.clientFactory,
    this.allowMissingApiKey = false,
  });

  final AiSettings settings;
  final DocumentGrounding grounding;
  final ReaderPrompts prompts;
  final ModelClient Function(AiSettings settings)? clientFactory;
  final bool allowMissingApiKey;

  @override
  String get id => 'ai.reader';

  @override
  String get label => 'readingAssistant';

  @override
  bool get enabled => settings.ready;

  @override
  Future<ReaderToolResult> run({
    required ReaderDocument document,
    required ReaderToolRequest request,
    AppLocalizations? l10n,
  }) async {
    final resolved = settings.withProjectDefaults();
    if (!resolved.enabled) {
      return ReaderToolResult.unavailable(
        l10n?.assistantDisabled ?? '阅读助手未启用。可在设置中打开。',
      );
    }
    if (!resolved.isReady(serverHasKey: allowMissingApiKey)) {
      return ReaderToolResult.unavailable(
        l10n?.assistantNotConfigured ?? '请先在设置中填写模型服务。',
      );
    }
    final searched =
        request.askDocument && (request.question?.trim().isNotEmpty ?? false)
        ? await grounding.fromSearch(
            document,
            query: request.question!.trim(),
            l10n: l10n,
          )
        : null;
    final context =
        searched?.context ??
        await grounding.fromDocument(
          document,
          range: request.range,
          locator: request.locator,
          l10n: l10n,
        );
    if (context.excerpt.isEmpty) {
      return ReaderToolResult.unavailable(l10n?.noExcerpt ?? '当前页没有可发送的摘录。');
    }
    final client =
        clientFactory?.call(resolved) ??
        OpenAiCompatibleClient(
          endpoint: resolved.endpoint,
          model: resolved.model,
          apiKey: resolved.apiKey,
        );
    final text = await client.complete(
      prompts.messages(
        kind: request.kind,
        grounding: context,
        question: request.question,
      ),
    );
    return ReaderToolResult(
      text: text,
      locatorLabel: context.locatorLabel,
      proposals: [
        for (final hit in searched?.hits ?? const <SearchResult>[])
          ReaderJumpProposal(
            locator: hit.locator,
            label: DocumentGrounding.locatorLabel(hit.locator, l10n: l10n),
          ),
      ],
    );
  }
}
