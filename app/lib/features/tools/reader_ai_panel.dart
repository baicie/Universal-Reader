import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/reader_runtime.dart';
import '../../l10n/l10n.dart';
import 'ai/ai_reader_tool.dart';
import 'ai/ai_settings.dart';
import 'ai/conversation_store.dart';
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
  String? error;
  bool sending = false;
  var previewStarted = false;
  List<ConversationTurn> turns = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!previewStarted) {
      previewStarted = true;
      _loadPreview();
      _loadHistory();
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

  Future<void> _loadHistory() async {
    try {
      final loaded = await ref
          .read(aiRuntimeProvider)
          .conversations
          .load(widget.document.metadata.id);
      if (!mounted) return;
      setState(() => turns = loaded);
    } catch (_) {
      // 损坏记录或读失败时显示错误，不把空历史当成“没有问过”。
      if (!mounted) return;
      setState(() {
        error = AppLocalizations.of(context).conversationUnavailable;
      });
    }
  }

  Future<void> _send() async {
    setState(() {
      sending = true;
      error = null;
    });
    final runtime = ref.read(aiRuntimeProvider);
    try {
      final tool = AiReaderTool(
        settings: widget.settings,
        allowMissingApiKey: runtime.allowMissingApiKey,
        clientFactory: runtime.modelClient,
      );
      final l10n = AppLocalizations.of(context);
      final result = await tool.run(
        document: widget.document,
        request: ReaderToolRequest(kind: kind, question: question.text),
        l10n: l10n,
      );
      if (!mounted) return;
      if (result.unavailable) {
        setState(() {
          sending = false;
          error = result.text;
        });
        return;
      }
      final next = await runtime.conversations.append(
        widget.document.metadata.id,
        ConversationTurn(
          kind: kind,
          question: kind == ReaderToolKind.ask ? question.text.trim() : '',
          reply: result.text,
          locatorLabel: result.locatorLabel ?? locatorLabel ?? '',
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        sending = false;
        turns = next;
        locatorLabel = result.locatorLabel ?? locatorLabel;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sending = false;
        error = AppLocalizations.of(context).requestFailed('$e');
      });
    }
  }

  String _kindLabel(AppLocalizations l10n, ReaderToolKind value) {
    return switch (value) {
      ReaderToolKind.summarize => l10n.summarize,
      ReaderToolKind.explain => l10n.explain,
      ReaderToolKind.translate => l10n.translate,
      ReaderToolKind.ask => l10n.ask,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(aiRuntimeProvider);
    final ready = widget.settings.isReady(serverHasKey: runtime.serverHasKey);
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
              if (turns.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l10n.conversationHistory,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: turns.isEmpty
                      ? SingleChildScrollView(
                          child: Text(
                            error ?? excerptPreview ?? l10n.readingExcerpt,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              color: error == null
                                  ? null
                                  : theme.colorScheme.error,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: turns.length + (error == null ? 0 : 1),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index >= turns.length) {
                              return Text(
                                error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  height: 1.5,
                                ),
                              );
                            }
                            final turn = turns[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  turn.question.isEmpty
                                      ? _kindLabel(l10n, turn.kind)
                                      : '${_kindLabel(l10n, turn.kind)} · ${turn.question}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (turn.locatorLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    turn.locatorLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  turn.reply,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ready
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
