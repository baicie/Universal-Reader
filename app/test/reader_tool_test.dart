import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderToolKind enum', () {
    test('lists every supported reader tool kind', () {
      expect(ReaderToolKind.values, [
        ReaderToolKind.summarize,
        ReaderToolKind.explain,
        ReaderToolKind.translate,
        ReaderToolKind.ask,
      ]);
    });

    test('every kind has a stable name', () {
      expect(ReaderToolKind.summarize.name, 'summarize');
      expect(ReaderToolKind.explain.name, 'explain');
      expect(ReaderToolKind.translate.name, 'translate');
      expect(ReaderToolKind.ask.name, 'ask');
    });
  });

  group('ReaderJumpProposal', () {
    test('carries its locator and label', () {
      const locator = EpubLocator(href: 'OEBPS/ch1.xhtml');
      const proposal = ReaderJumpProposal(locator: locator, label: 'chapter-1');
      expect(proposal.locator, same(locator));
      expect(proposal.label, 'chapter-1');
    });
  });

  group('ReaderToolRequest', () {
    test(
      'defaults askDocument to false and range/locator/question to null',
      () {
        const request = ReaderToolRequest(kind: ReaderToolKind.translate);
        expect(request.kind, ReaderToolKind.translate);
        expect(request.question, isNull);
        expect(request.locator, isNull);
        expect(request.range, isNull);
        expect(request.askDocument, isFalse);
      },
    );

    test('every field can be supplied explicitly', () {
      const range = DocumentRange(
        start: EpubLocator(href: 'start.xhtml'),
        end: EpubLocator(href: 'end.xhtml'),
      );
      const locator = TextLocator(offset: 42);
      const request = ReaderToolRequest(
        kind: ReaderToolKind.ask,
        question: 'what is going on?',
        range: range,
        locator: locator,
        askDocument: true,
      );
      expect(request.kind, ReaderToolKind.ask);
      expect(request.question, 'what is going on?');
      expect(request.range, same(range));
      expect(request.locator, same(locator));
      expect(request.askDocument, isTrue);
    });
  });

  group('ReaderToolResult', () {
    test('default constructor keeps every optional field in a known state', () {
      const result = ReaderToolResult(text: 'hello');
      expect(result.text, 'hello');
      expect(result.locatorLabel, isNull);
      expect(result.unavailable, isFalse);
      expect(result.proposals, isEmpty);
    });

    test('unavailable factory marks unavailable and clears other fields', () {
      const result = ReaderToolResult.unavailable(
        'turn on the assistant first',
      );
      expect(result.unavailable, isTrue);
      expect(result.text, 'turn on the assistant first');
      expect(result.locatorLabel, isNull);
      expect(result.proposals, isEmpty);
    });

    test('exposes supplied proposals verbatim', () {
      const proposal = ReaderJumpProposal(
        locator: PdfLocator(page: 3),
        label: 'page 3',
      );
      final result = ReaderToolResult(
        text: 'see page 3',
        locatorLabel: 'p.3',
        proposals: [proposal],
      );
      expect(result.proposals, [proposal]);
      expect(result.locatorLabel, 'p.3');
      expect(result.unavailable, isFalse);
    });
  });
}
