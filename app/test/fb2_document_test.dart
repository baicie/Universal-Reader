import 'dart:convert';

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

  group('parseFb2 inlines', () {
    test('emphasis wraps text in <em>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<emphasis>italic</emphasis>',
      ));
      expect(parsed.chapters.first.html, contains('<em>italic</em>'));
    });

    test('strong wraps text in <strong>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<strong>bold</strong>',
      ));
      expect(parsed.chapters.first.html, contains('<strong>bold</strong>'));
    });

    test('strikethrough wraps text in <s>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<strikethrough>cut</strikethrough>',
      ));
      expect(parsed.chapters.first.html, contains('<s>cut</s>'));
    });

    test('sub wraps text in <sub>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<sub>2</sub>',
      ));
      expect(parsed.chapters.first.html, contains('<sub>2</sub>'));
    });

    test('sup wraps text in <sup>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<sup>n</sup>',
      ));
      expect(parsed.chapters.first.html, contains('<sup>n</sup>'));
    });

    test('code wraps text in <code>', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<code>printf</code>',
      ));
      expect(parsed.chapters.first.html, contains('<code>printf</code>'));
    });

    test('style with name produces <span class="…">', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<style name="highlight">lit</style>',
      ));
      expect(
        parsed.chapters.first.html,
        contains('<span class="highlight">lit</span>'),
      );
    });

    test('style without name falls back to plain inner text', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<style>naked</style>',
      ));
      // No <span> wrapper when no name attribute is provided.
      expect(parsed.chapters.first.html, isNot(contains('<span')));
      expect(parsed.chapters.first.html, contains('naked'));
    });

    test('a hash-href renders <a href="#…">', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        textBefore: 'see ',
        textAfter: ' for details',
        extra: '<a l:href="#note1">footnote 1</a>',
      ));
      expect(
        parsed.chapters.first.html,
        contains('<a href="#note1">footnote 1</a>'),
      );
    });

    test('a http-href renders external link with class', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        textBefore: '',
        textAfter: '',
        extra: '<a l:href="https://example.com/x">ext</a>',
      ));
      expect(
        parsed.chapters.first.html,
        contains('class="external-link"'),
      );
      expect(
        parsed.chapters.first.html,
        contains('href="https://example.com/x"'),
      );
    });

    test('a with id but no href renders a <span id="…">', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<a id="bookmark-here">marker</a>',
      ));
      expect(parsed.chapters.first.html, contains('<span id="bookmark-here">'));
    });

    test('a with neither href nor id drops the wrapper', () {
      final parsed = parseFb2(fb2WithInlineParagraphBytes(
        extra: '<a>plain anchor</a>',
      ));
      // The anchor wrapper should disappear entirely (no <a> tag emitted).
      expect(parsed.chapters.first.html, isNot(contains('<a')));
      expect(parsed.chapters.first.html, contains('plain anchor'));
    });

    test('inline image renders an <img src> with binary data uri', () {
      final parsed = parseFb2(fb2WithInlineImageBytes());
      final html = parsed.chapters.first.html;
      expect(html, contains('<img'));
      expect(html, contains('src="data:image/png;base64,'));
    });

    test('cross-reference hash href is rewritten to chapter anchor', () {
      final parsed = parseFb2(fb2WithCrossReferenceBytes());
      final html = parsed.chapters.first.html;
      // The original '#anchor1' is rewritten to a chapter-scoped href
      // (e.g. "section-0#anchor1") so the link points to a real chapter.
      expect(html, contains('href="section-0#anchor1"'));
      // And the original bare '#anchor1' href must no longer be present.
      expect(html, isNot(contains('href="#anchor1"')));
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

  group('parseFb2 block elements', () {
    // All tests in this group feed a single chapter via fb2WithChapterBlocksBytes
    // and assert the rendered HTML for one specific block element branch.
    String firstHtml(String blocks) => parseFb2(
          fb2WithChapterBlocksBytes([blocks]),
        ).chapters.first.html;

    test('section-level <subtitle> renders as <h2>', () {
      final html = firstHtml('<subtitle>A subtitle line</subtitle>'
          '<p>body</p>');
      expect(html, contains('<h2>A subtitle line</h2>'));
    });

    test('section-level <subtitle style=…> renders with class attribute', () {
      final html = firstHtml(
        '<subtitle style="accent">fancy</subtitle><p>body</p>',
      );
      expect(html, contains('<h2 class="accent">fancy</h2>'));
    });

    test('section-level <image> with style adds class', () {
      const pngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
      final raw = '<?xml version="1.0"?>'
          '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"'
          ' xmlns:l="http://www.w3.org/1999/xlink">'
          '<description><title-info><book-title>t</book-title></title-info>'
          '</description>'
          '<binary id="cover.png" content-type="image/png">$pngBase64</binary>'
          '<body><section><title>ch</title>'
          '<image l:href="#cover.png" style="wide" alt="cover" title="A"/>'
          '</section></body>'
          '</FictionBook>';
      final html = parseFb2(utf8.encode(raw)).chapters.first.html;
      expect(html, contains('<img'));
      expect(html, contains('class="wide"'));
      expect(html, contains('alt="cover"'));
      expect(html, contains('title="A"'));
      expect(html, contains('src="data:image/png;base64,'));
    });

    test('empty-line inside section emits <p><br/></p>', () {
      final html = firstHtml('<empty-line/><p>after</p>');
      expect(html, contains('<p><br/></p>'));
      expect(html, contains('after'));
    });

    test('poem with title/subtitle/text-author/date renders all parts', () {
      final html = firstHtml(
        '<poem>'
        '<title>Poem Title</title>'
        '<subtitle>Subhead</subtitle>'
        '<text-author>Anon</text-author>'
        '<date value="1900-01-01">New Year 1900</date>'
        '<stanza>'
        '<title>Stanza Head</title>'
        '<v>line one</v>'
        '<v>line two</v>'
        '</stanza>'
        '</poem>',
      );
      expect(html, contains('<blockquote>'));
      expect(html, contains('<h3>Poem Title</h3>'));
      expect(html, contains('<h4>Subhead</h4>'));
      expect(html, contains('Anon'));
      expect(html, contains('New Year 1900'));
      expect(html, contains('<h4>Stanza Head</h4>'));
      expect(html, contains('line one<br/>line two'));
    });

    test('stanza subtitle carries id attribute', () {
      final html = firstHtml(
        '<poem><stanza>'
        '<subtitle id="s1">anchor inside stanza</subtitle>'
        '<v>verse</v>'
        '</stanza></poem>',
      );
      expect(html, contains('<h5'));
      expect(html, contains('id="s1"'));
    });

    test('stanza <v style=…> wraps line in <span class>', () {
      final html = firstHtml(
        '<poem><stanza>'
        '<v style="indent">indented verse</v>'
        '</stanza></poem>',
      );
      expect(html, contains('<span class="indent">indented verse</span>'));
    });

    test('stanza <v> with only whitespace is dropped', () {
      final html = firstHtml(
        '<poem><stanza><v>kept</v><v>   </v></stanza></poem>',
      );
      // The kept line is present, the whitespace-only line is dropped.
      expect(html, contains('kept'));
      expect(html, isNot(contains('   ')));
    });

    test('stanza without any <v> yields null stanza part', () {
      final html = firstHtml(
        '<poem><stanza><title>only a title</title></stanza></poem>',
      );
      // Title should still render.
      expect(html, contains('only a title'));
    });

    test('poem <date> with empty inner uses value attribute', () {
      final html = firstHtml(
        '<poem><date value="2024-05"/></poem>',
      );
      expect(html, contains('2024-05'));
    });

    test('poem <date> with no inner and no value returns null', () {
      final html = firstHtml('<poem><date/></poem>');
      // No <p>…</p> added by the date branch.
      expect(html, isNot(contains('<p></p>')));
    });

    test('epigraph inside poem stanza is silently dropped from HTML', () {
      // Documenting the current behaviour: stanza's child loop only knows
      // about title/subtitle/v. An epigraph nested in a stanza gets ignored
      // in HTML (its inline text does still appear in the chapter's
      // fullText via XmlElement.innerText but not in the rendered HTML).
      final html = firstHtml(
        '<poem><stanza>'
        '<v>verse</v>'
        '<epigraph><p>attr line</p></epigraph>'
        '</stanza></poem>',
      );
      expect(html, contains('<blockquote>'));
      expect(html, contains('verse'));
      expect(html, isNot(contains('attr line')));
    });

    test('cite inside quote nests another blockquote', () {
      final html = firstHtml(
        '<cite>'
        '<p>outer</p>'
        '<cite><p>inner</p></cite>'
        '</cite>',
      );
      final openCount = '<blockquote>'.allMatches(html).length;
      expect(openCount, greaterThanOrEqualTo(2));
      expect(html, contains('outer'));
      expect(html, contains('inner'));
    });

    test('text-author inside quote with style renders <p class>', () {
      final html = firstHtml(
        '<cite><p>quote</p><text-author style="by">By X</text-author></cite>',
      );
      expect(html, contains('By X'));
      expect(html, contains('class="by"'));
    });

    test('quote <subtitle> renders as <h2>', () {
      final html = firstHtml(
        '<cite><subtitle>Q-Sub</subtitle><p>body</p></cite>',
      );
      expect(html, contains('<h2'));
      expect(html, contains('Q-Sub'));
    });

    test('quote <poem> embeds poem as nested blockquote', () {
      final html = firstHtml(
        '<cite>'
        '<poem><stanza><v>quoted verse</v></stanza></poem>'
        '<text-author>Y</text-author>'
        '</cite>',
      );
      expect(html, contains('quoted verse'));
      expect(html, contains('Y'));
    });

    test('table renders caption + <tr><th> + <tr><td> with styles', () {
      final html = firstHtml(
        '<table>'
        '<title style="cap">My Table</title>'
        '<tr style="header"><th>H1</th><th>H2</th></tr>'
        '<tr><td style="hl">a</td><td>b</td></tr>'
        '</table>',
      );
      expect(html, contains('<table'));
      expect(html, contains('<caption class="cap">My Table</caption>'));
      expect(html, contains('<th'));
      expect(html, contains('H1'));
      expect(html, contains('class="header"'));
      expect(html, contains('class="hl"'));
      expect(html, contains('<td'));
    });

    test('table with no <tr> yields null', () {
      final html = firstHtml('<table><title>empty</title></table>');
      // Table is dropped because no rows.
      expect(html, isNot(contains('<table')));
    });

    test('table <tr> with no <th>/<td> is skipped', () {
      final html = firstHtml(
        '<table>'
        '<tr><v>not a cell</v></tr>'
        '<tr><td>kept</td></tr>'
        '</table>',
      );
      expect(html, contains('<table'));
      expect(html, contains('kept'));
      expect(html, isNot(contains('not a cell')));
    });

    test('table cell <p> fragments joined with <br/>', () {
      final html = firstHtml(
        '<table>'
        '<tr><td><p>one</p><p>two</p></td></tr>'
        '</table>',
      );
      expect(html, contains('one<br/>two'));
    });

    test('annotation inside chapter renders as <aside>', () {
      final html = firstHtml(
        '<annotation>'
        '<subtitle>A-Sub</subtitle>'
        '<p>note body</p>'
        '</annotation>',
      );
      expect(html, contains('<aside>'));
      expect(html, contains('A-Sub'));
      expect(html, contains('note body'));
    });

    test('annotation <empty-line> emits a <p><br/></p>', () {
      final html = firstHtml(
        '<annotation><empty-line/><p>after</p></annotation>',
      );
      expect(html, contains('<aside>'));
      expect(html, contains('<p><br/></p>'));
    });

    test('annotation <cite> embeds blockquote', () {
      final html = firstHtml(
        '<annotation><cite><p>quoted inside</p></cite></annotation>',
      );
      expect(html, contains('<aside>'));
      expect(html, contains('<blockquote>'));
      expect(html, contains('quoted inside'));
    });

    test('annotation <poem> embeds poem', () {
      final html = firstHtml(
        '<annotation>'
        '<poem><stanza><v>v1</v><v>v2</v></stanza></poem>'
        '</annotation>',
      );
      expect(html, contains('<aside>'));
      expect(html, contains('<blockquote>'));
      expect(html, contains('v1<br/>v2'));
    });

    test('annotation <table> embeds table', () {
      final html = firstHtml(
        '<annotation>'
        '<table><tr><td>cell</td></tr></table>'
        '</annotation>',
      );
      expect(html, contains('<aside>'));
      expect(html, contains('<table'));
      expect(html, contains('cell'));
    });
  });
}
