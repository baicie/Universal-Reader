import '../../../core/reader_runtime.dart';
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
  });

  final AiSettings settings;
  final DocumentGrounding grounding;
  final ReaderPrompts prompts;
  final ModelClient Function(AiSettings settings)? clientFactory;

  @override
  String get id => 'ai.reader';

  @override
  String get label => '阅读助手';

  @override
  bool get enabled => settings.ready;

  @override
  Future<ReaderToolResult> run({
    required ReaderDocument document,
    required ReaderToolRequest request,
  }) async {
    if (!settings.enabled) {
      return const ReaderToolResult.unavailable('阅读助手未启用。可在设置中打开。');
    }
    if (settings.endpoint.trim().isEmpty || settings.model.trim().isEmpty) {
      return const ReaderToolResult.unavailable('请先在设置中填写接口地址和模型名称。');
    }
    final context = await grounding.fromDocument(
      document,
      range: request.range,
      locator: request.locator,
    );
    if (context.excerpt.isEmpty) {
      return const ReaderToolResult.unavailable('当前页没有可发送的摘录。');
    }
    final client =
        clientFactory?.call(settings) ??
        OpenAiCompatibleClient(
          endpoint: settings.endpoint,
          model: settings.model,
          apiKey: settings.apiKey,
        );
    final text = await client.complete(
      prompts.messages(
        kind: request.kind,
        grounding: context,
        question: request.question,
      ),
    );
    return ReaderToolResult(text: text, locatorLabel: context.locatorLabel);
  }
}
