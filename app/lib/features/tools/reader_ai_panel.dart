import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/reader_runtime.dart';
import 'ai/ai_reader_tool.dart';
import 'ai/ai_settings.dart';
import 'ai/grounding.dart';
import 'reader_tool.dart';

class ReaderAiPanel extends ConsumerStatefulWidget {
  const ReaderAiPanel({
    required this.document,
    required this.settings,
    super.key,
  });

  final ReaderDocument document;
  final AiSettings settings;

  @override
  ConsumerState<ReaderAiPanel> createState() => _ReaderAiPanelState();
}

class _ReaderAiPanelState extends ConsumerState<ReaderAiPanel> {
  ReaderToolKind kind = ReaderToolKind.summarize;
  final question = TextEditingController();
  String? locatorLabel;
  String? excerptPreview;
  String? reply;
  String? error;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final grounding = await const DocumentGrounding().fromDocument(
      widget.document,
    );
    if (!mounted) return;
    setState(() {
      locatorLabel = grounding.locatorLabel;
      excerptPreview = grounding.excerpt;
    });
  }

  Future<void> _send() async {
    setState(() {
      sending = true;
      error = null;
      reply = null;
    });
    try {
      final tool = AiReaderTool(settings: widget.settings);
      final result = await tool.run(
        document: widget.document,
        request: ReaderToolRequest(kind: kind, question: question.text),
      );
      if (!mounted) return;
      setState(() {
        sending = false;
        if (result.unavailable) {
          error = result.text;
        } else {
          reply = result.text;
          locatorLabel = result.locatorLabel ?? locatorLabel;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sending = false;
        error = '请求失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: GestureDetector(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '问这一页',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  locatorLabel == null
                      ? '将发送当前章节摘录，不上整本书。'
                      : '定位：$locatorLabel。将发送当前摘录，不上整本书。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final item in [
                      (ReaderToolKind.summarize, '总结'),
                      (ReaderToolKind.explain, '解释'),
                      (ReaderToolKind.translate, '翻译'),
                      (ReaderToolKind.ask, '提问'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: kind == item.$1,
                        onSelected: (_) => setState(() => kind = item.$1),
                      ),
                  ],
                ),
              ),
              if (kind == ReaderToolKind.ask)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: question,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '输入关于这一页的问题'),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Text(
                      reply ?? error ?? excerptPreview ?? '正在读取当前摘录…',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: widget.settings.ready
                    ? FilledButton(
                        onPressed: sending ? null : _send,
                        child: Text(sending ? '发送中…' : '发送摘录'),
                      )
                    : OutlinedButton(
                        onPressed: () => context.push('/settings'),
                        child: const Text('到设置中启用阅读助手'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
