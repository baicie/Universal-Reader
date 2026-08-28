import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/reader_runtime.dart';
import '../../l10n/l10n.dart';
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
  var previewStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!previewStarted) {
      previewStarted = true;
      _loadPreview();
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final grounding = await const DocumentGrounding().fromDocument(
      widget.document,
      l10n: AppLocalizations.of(context),
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
      final l10n = AppLocalizations.of(context);
      final result = await tool.run(
        document: widget.document,
        request: ReaderToolRequest(kind: kind, question: question.text),
        l10n: l10n,
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
        error = AppLocalizations.of(context).requestFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  l10n.askThisPage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  locatorLabel == null
                      ? l10n.sendExcerptHint
                      : l10n.sendExcerptHintLocated(locatorLabel!),
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
                      (ReaderToolKind.summarize, l10n.summarize),
                      (ReaderToolKind.explain, l10n.explain),
                      (ReaderToolKind.translate, l10n.translate),
                      (ReaderToolKind.ask, l10n.ask),
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
                    decoration: InputDecoration(hintText: l10n.askQuestionHint),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Text(
                      reply ?? error ?? excerptPreview ?? l10n.readingExcerpt,
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
                        child: Text(sending ? l10n.sending : l10n.sendExcerpt),
                      )
                    : OutlinedButton(
                        onPressed: () => context.push('/settings'),
                        child: Text(l10n.enableAssistantInSettings),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
