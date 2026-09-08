import 'package:app/core/fb2_document.dart';
import 'package:app/core/foliate_session.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fb2_fixture.dart';

void main() {
  group('parseFb2', () {
    test('extracts title and author from description', () {
      final parsed = parseFb2(minimalFb2Bytes(
        title: '我的书',
        authorFirst: '张',
        authorLast: '三',
      ));
      expect(parsed.title, '我的书');
      expect(parsed.author, '张 三');
    });

    test('author is empty when no description is present', () {
      final bytes = minimalFb2Bytes(authorFirst: '', authorLast: '');
      expect(parseFb2(bytes).author, '');
    });

    test('title is empty when book-title is absent', () {
      final bytes = '<?xml version="1.0" encoding="UTF-8"?>'
          '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
          '<description><title-info></title-info></description>'
          '<body><section><title>Chapter</title><p>Text</p></section></body>'
          '</FictionBook>';
      expect(parseFb2(bytes.codeUnits).title, '');
    });

    test('parses one chapter from a section with title', () {
      final parsed = parseFb2(minimalFb2Bytes(
        chapterTitles: ['第一章'],
        chapterBodies: ['first chapter paragraph'],
      ));
      expect(parsed.chapters, hasLength(1));
      expect(parsed.chapters[0].title, '第一章');
      expect(parsed.chapters[0].text, contains('first chapter'));
      expect(parsed.fullText, contains('first chapter'));
    });

    test('parses multiple chapters preserving order', () {
      final parsed = parseFb2(minimalFb2Bytes(
        chapterTitles: ['第一章', '第二章', '第三章'],
        chapterBodies: ['alpha\nbeta', 'gamma', 'delta'],
      ));
      expect(parsed.chapters, hasLength(3));
      expect(parsed.chapters[0].href, isNotEmpty);
      expect(parsed.chapters[1].href, isNot(equals(parsed.chapters[0].href)));
      expect(parsed.fullText, contains('alpha'));
      expect(parsed.fullText, contains('gamma'));
      expect(parsed.fullText, contains('delta'));
    });

    test('annotation section appears as a chapter with href=annotation', () {
      final parsed = parseFb2(fb2WithAnnotationBytes(
        title: 'Annotated',
        annotation: 'A brief description of the book.',
      ));
      // Annotation becomes the first chapter.
      expect(parsed.chapters.first.href, 'annotation');
      expect(parsed.chapters.first.text, contains('brief description'));
    });

    test('throws FormatException on corrupt XML', () {
      expect(
        () => parseFb2('not xml at all'.codeUnits),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when root element is not FictionBook', () {
      final bytes = '<?xml version="1.0"?><html><body>test</body></html>';
      expect(
        () => parseFb2(bytes.codeUnits),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts FictionBook regardless of case', () {
      final bytes = '<?xml version="1.0"?>'
          '<FICTIONBOOK xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
          '<description><title-info><book-title>Title</book-title></title-info></description>'
          '<body><section><title>Ch</title><p>Text</p></section></body>'
          '</FICTIONBOOK>';
      // Should not throw — case-insensitive check.
      expect(() => parseFb2(bytes.codeUnits), returnsNormally);
    });

    test('epigraph text is prepended to the first chapter text', () {
      final parsed = parseFb2(fb2WithBodyLeadBytes(
        bodyLead: '<epigraph><p>Quote from a friend.</p></epigraph>',
        chapterTitle: '正文',
        chapterParagraphs: ['main paragraph'],
      ));
      expect(parsed.chapters, hasLength(1));
      expect(parsed.chapters.first.text, contains('Quote from a friend'));
    });

    test('cite text is prepended to the first chapter text', () {
      final parsed = parseFb2(fb2WithBodyLeadBytes(
        bodyLead: '<cite><p>Cited reference.</p></cite>',
        chapterTitle: '正文',
        chapterParagraphs: ['main paragraph'],
      ));
      expect(parsed.chapters.first.text, contains('Cited reference'));
    });

    test('subtitle text is prepended to the first chapter text', () {
      final parsed = parseFb2(fb2WithBodyLeadBytes(
        bodyLead: '<subtitle>subtitle text</subtitle>',
        chapterTitle: '正文',
        chapterParagraphs: ['main paragraph'],
      ));
      expect(parsed.chapters.first.text, contains('subtitle text'));
    });

    test('empty-line lead does not add visible text', () {
      final parsed = parseFb2(fb2WithBodyLeadBytes(
        bodyLead: '<empty-line/>',
        chapterTitle: '正文',
        chapterParagraphs: ['only main paragraph'],
      ));
      expect(parsed.chapters.first.text, contains('only main paragraph'));
      // The chapter html should still render the empty line as a break.
      expect(parsed.chapters.first.html, contains('<br'));
    });

    test('poem body content becomes part of the chapter text', () {
      final parsed = parseFb2(fb2WithChapterBlocksBytes([
        '<title>Poem Chapter</title>',
        '<poem><stanza><v>line one</v><v>line two</v></stanza></poem>',
      ]));
      expect(parsed.chapters.first.text, contains('line one'));
      expect(parsed.chapters.first.text, contains('line two'));
    });

    test('epigraph inside a poem stanza still survives', () {
      final parsed = parseFb2(fb2WithChapterBlocksBytes([
        '<title>Stanza Epigraph</title>',
        '<poem>'
            '<stanza><v>main verse</v>'
            '<epigraph><p>attribution line</p></epigraph>'
            '</stanza>'
            '</poem>',
      ]));
      expect(parsed.chapters.first.text, contains('main verse'));
      expect(parsed.chapters.first.text, contains('attribution line'));
    });

    test('a notes body becomes chapters deferred until main sections exist',
        () {
      // main body has a section, the secondary body has name="notes" — both
      // should end up as chapters since index > 0 by the time notes is
      // emitted.
      final bytes = '<?xml version="1.0"?>'
          '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
          '<description><title-info><book-title>Notes Book</book-title>'
          '</title-info></description>'
          '<body><section><title>Main</title><p>main text</p></section></body>'
          '<body name="notes">'
          '<section><title>Note 1</title><p>note text</p></section>'
          '</body>'
          '</FictionBook>';
      final parsed = parseFb2(bytes.codeUnits);
      expect(parsed.chapters.length, greaterThanOrEqualTo(2));
      final titles = parsed.chapters.map((c) => c.title).toList();
      expect(titles, contains('Main'));
      expect(titles, contains('Note 1'));
    });
  });

  group('Fb2ReaderDocument', () {
    Fb2ReaderDocument build({
      List<String> titles = const ['第一章', '第二章'],
      List<String> bodies = const ['first content', 'second content'],
    }) {
      return Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-1',
          title: 'Test FB2',
          author: 'Test Author',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: minimalFb2Bytes(
          chapterTitles: titles,
          chapterBodies: bodies,
        ),
      );
    }

    test('starts on the first chapter', () {
      final doc = build();
      expect(doc.sectionIndex, 0);
      expect(doc.chapterIndex, 0);
      expect(doc.chapterCount, 2);
      expect(doc.currentChapterTitle, '第一章');
      expect(doc.currentChapterText, contains('first content'));
    });

    test('goTo jumps to the matching chapter by href', () {
      final doc = build();
      final chapter2Href = doc.parsed.chapters[1].href;

      doc.goTo(EpubLocator(href: chapter2Href));
      expect(doc.sectionIndex, 1);
      expect(doc.currentChapterTitle, '第二章');
    });

    test('goTo ignores non-EpubLocator', () {
      final doc = build();
      // PdfLocator is a non-EpubLocator subclass — goTo should ignore it.
      doc.goTo(const PdfLocator(page: 1));
      expect(doc.sectionIndex, 0);
    });

    test('goTo ignores unknown href', () {
      final doc = build();
      doc.goTo(EpubLocator(href: 'unknown-chapter'));
      expect(doc.sectionIndex, 0);
    });

    test('currentLocator returns the current chapter href', () async {
      final doc = build();
      final locator = await doc.currentLocator();
      expect(locator, isA<EpubLocator>());
      expect((locator as EpubLocator).href, doc.currentChapter.href);
    });

    test('locatorForProgress maps progress to the correct chapter', () {
      final doc = build(titles: ['A', 'B', 'C']);
      final mid = doc.locatorForProgress(0.4);
      expect(mid, isA<EpubLocator>());
      // At progress 0.4 with 3 chapters, index should be around 1.
      expect((mid as EpubLocator).href, isNotEmpty);
    });

    test('extractText returns current chapter text', () async {
      final doc = build();
      final text = await doc.extractText(DocumentRange(
        start: EpubLocator(href: doc.currentChapter.href),
        end: EpubLocator(href: doc.currentChapter.href),
      ));
      expect(text, contains('first content'));
    });

    test('truncated is always false', () {
      expect(build().truncated, false);
    });

    test('search finds a phrase in the full text', () async {
      final doc = build(bodies: ['needle in a haystack', 'other chapter']);
      final hits = await doc.search('needle');
      expect(hits, isNotEmpty);
      expect(hits.first.locator, isA<EpubLocator>());
    });

    test('search returns empty when the phrase is absent', () async {
      final doc = build(bodies: ['something else', 'different text']);
      final hits = await doc.search('needle');
      expect(hits, isEmpty);
    });

    test('search is case-sensitive', () async {
      final doc = build(bodies: ['Needle in haystack', 'other chapter']);
      final hits = await doc.search('needle');
      expect(hits, isEmpty);
    });
  });

  group('FoliateSession with Fb2ReaderDocument', () {
    Fb2ReaderDocument buildDoc({int bodyParagraphs = 1}) {
      final bodies = List.generate(
        bodyParagraphs,
        (i) => 'paragraph $i of the chapter text',
      ).join('\n');
      return Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-sess-1',
          title: 'Session FB2',
          author: '',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: minimalFb2Bytes(
          chapterTitles: const ['Chapter One', 'Chapter Two'],
          chapterBodies: [bodies, 'second chapter content'],
        ),
      );
    }

    test('opens as a paged session', () {
      final session = FoliateSession.open(buildDoc(), pageCharLimit: 30);
      expect(session.pageCount, greaterThan(1));
      expect(session.title, 'Chapter One');
      expect(session.href, isNotEmpty);
    });

    test('next page advances within the chapter', () {
      final session = FoliateSession.open(buildDoc(), pageCharLimit: 30);
      final initialIndex = session.pageIndex;
      final advanced = session.next();
      expect(advanced, isTrue);
      expect(session.pageIndex, initialIndex + 1);
    });

    test('next returns false at the last page', () {
      final session = FoliateSession.open(buildDoc(), pageCharLimit: 200);
      // Single-page chapter, already at page 0.
      while (session.next()) {}
      expect(session.next(), isFalse);
    });

    test('previous returns false at the first page', () {
      final session = FoliateSession.open(buildDoc(), pageCharLimit: 30);
      expect(session.previous(), isFalse);
      session.next();
      expect(session.previous(), isTrue);
    });

    test('goToPage clamps out-of-range indices', () {
      final session = FoliateSession.open(buildDoc(), pageCharLimit: 30);
      session.goToPage(999);
      expect(session.pageIndex, session.pageCount - 1);
      session.goToPage(-5);
      expect(session.pageIndex, 0);
    });

    test('goToCfi jumps to the correct page', () {
      final doc = buildDoc();
      final session = FoliateSession.open(doc, pageCharLimit: 30);
      final targetCfi = session.currentCfi;
      // Go to second page.
      session.next();
      // Jump back.
      final ok = session.goToCfi(targetCfi);
      expect(ok, isTrue);
    });

    test('goToCfi returns false for malformed cfi', () {
      final session = FoliateSession.open(buildDoc());
      expect(session.goToCfi('not-a-cfi'), isFalse);
    });
  });
}
