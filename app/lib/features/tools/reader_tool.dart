import '../../core/models.dart';
import '../../core/reader_runtime.dart';

enum ReaderToolKind { summarize, explain, translate, ask }

class ReaderJumpProposal {
  const ReaderJumpProposal({required this.locator, required this.label});

  final Locator locator;
  final String label;
}

class ReaderToolRequest {
  const ReaderToolRequest({
    required this.kind,
    this.question,
    this.range,
    this.locator,
    this.askDocument = false,
  });

  final ReaderToolKind kind;
  final String? question;
  final DocumentRange? range;
  final Locator? locator;
  final bool askDocument;
}

class ReaderToolResult {
  const ReaderToolResult({
    required this.text,
    this.locatorLabel,
    this.unavailable = false,
    this.proposals = const [],
  });

  const ReaderToolResult.unavailable(String message)
    : text = message,
      locatorLabel = null,
      unavailable = true,
      proposals = const [];

  final String text;
  final String? locatorLabel;
  final bool unavailable;
  final List<ReaderJumpProposal> proposals;
}

abstract interface class ReaderTool {
  String get id;
  String get label;
  bool get enabled;

  Future<ReaderToolResult> run({
    required ReaderDocument document,
    required ReaderToolRequest request,
  });
}
